// Mini painel de status do ESP32
// - Conecta no Wi-Fi de casa
// - Consulta https://usestl.com/health a cada POLL_MS
// - Mostra o resultado no monitor serial, no LED onboard e numa página web
//   servida pelo próprio ESP32 (http://<ip>/ ou http://esp32-painel.local/)

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <ArduinoJson.h>

#include "secrets.h"      // WIFI_SSID / WIFI_PASS (arquivo fora do git)
#include "dashboard.h"    // página HTML do painel

static const char* HEALTH_URL = "https://usestl.com/health";
static const char* MDNS_NAME  = "esp32-painel";
static const uint32_t POLL_MS = 30000;   // intervalo entre consultas
// GPIO 2 é o DC do display nesta placa; o feedback visual fica no LED RGB (display.h)

WebServer server(80);

// ---------- estado compartilhado ----------
struct Check     { String name; String status; int latencyMs; };
struct Operation { String name; String status; int ok; int fail; float rate; };

struct State {
  String  overall   = "unknown";   // ok / degraded / error / unknown
  int     httpCode  = 0;
  String  error;                   // última mensagem de erro
  uint32_t lastPoll = 0;           // millis() da última consulta concluída
  uint32_t lastOk   = 0;           // millis() da última consulta bem-sucedida
  int     pollMs    = 0;           // duração da última requisição
  uint32_t polls    = 0;
  uint32_t failures = 0;
  Check     checks[8];     int nChecks = 0;
  Operation ops[16];       int nOps    = 0;
} st;

#include "display.h"   // tela ILI9341 + touch + LED RGB (precisa de State)

// ---------- LED RGB ----------
// verde fixo: tudo ok | vermelho piscando: problema | azul piscando: sem wifi / sem dados
void updateLed() {
  static uint32_t last = 0; static bool on = false;
  bool wifi = WiFi.status() == WL_CONNECTED;
  if (wifi && st.overall == "ok") { ledRGB(false, true, false); return; }
  uint32_t period = (!wifi || st.overall == "unknown") ? 1000 : 150;
  if (millis() - last >= period) { last = millis(); on = !on; }
  if (!wifi || st.overall == "unknown") ledRGB(false, false, on); else ledRGB(on, false, false);
}

// ---------- Wi-Fi ----------
void connectWifi() {
  Serial.printf("\n[wifi] conectando em \"%s\"", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.setHostname(MDNS_NAME);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    updateLed();
    delay(250);
    Serial.print('.');
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[wifi] conectado  ip=%s  rssi=%d dBm\n",
                  WiFi.localIP().toString().c_str(), WiFi.RSSI());
  } else {
    Serial.printf("[wifi] falhou (status=%d). Lembre: ESP32 só fala em 2.4 GHz.\n", WiFi.status());
  }
}

// ---------- consulta à API ----------
bool pollHealth() {
  if (WiFi.status() != WL_CONNECTED) { st.error = "sem wifi"; return false; }

  WiFiClientSecure client;
  client.setInsecure();            // não valida o certificado (simplifica; ver README)
  HTTPClient http;
  http.setTimeout(10000);
  http.setUserAgent("esp32-painel/1.0");

  uint32_t t0 = millis();
  if (!http.begin(client, HEALTH_URL)) { st.error = "http.begin falhou"; return false; }
  int code = http.GET();
  st.httpCode = code;
  st.pollMs   = millis() - t0;

  if (code != HTTP_CODE_OK) {
    st.error = String("HTTP ") + code + " " + HTTPClient::errorToString(code);
    http.end();
    return false;
  }

  String body = http.getString();
  http.end();

  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, body);
  if (err) { st.error = String("json: ") + err.c_str(); return false; }

  st.overall = doc["status"] | "unknown";

  st.nChecks = 0;
  for (JsonPair kv : doc["checks"].as<JsonObject>()) {
    if (st.nChecks >= 8) break;
    Check& c = st.checks[st.nChecks++];
    c.name      = kv.key().c_str();
    c.status    = kv.value()["status"]    | "?";
    c.latencyMs = kv.value()["latencyMs"] | -1;
  }

  st.nOps = 0;
  for (JsonPair kv : doc["operations"].as<JsonObject>()) {
    if (st.nOps >= 16) break;
    Operation& o = st.ops[st.nOps++];
    o.name   = kv.key().c_str();
    o.status = kv.value()["status"] | "?";
    o.ok     = kv.value()["ok"]     | 0;
    o.fail   = kv.value()["fail"]   | 0;
    o.rate   = kv.value()["rate"]   | 0.0f;
  }

  st.error = "";
  return true;
}

void printSerialDashboard() {
  Serial.println("\n==================== usestl.com/health ====================");
  Serial.printf("geral: %-8s  http=%d  %d ms  consultas=%u  falhas=%u\n",
                st.overall.c_str(), st.httpCode, st.pollMs, st.polls, st.failures);
  if (st.error.length()) Serial.printf("erro: %s\n", st.error.c_str());
  Serial.println("-- checks --");
  for (int i = 0; i < st.nChecks; i++)
    Serial.printf("  %-10s %-8s %5d ms\n", st.checks[i].name.c_str(),
                  st.checks[i].status.c_str(), st.checks[i].latencyMs);
  Serial.println("-- operations --");
  for (int i = 0; i < st.nOps; i++)
    Serial.printf("  %-10s %-8s ok=%-5d fail=%-4d rate=%.1f%%\n", st.ops[i].name.c_str(),
                  st.ops[i].status.c_str(), st.ops[i].ok, st.ops[i].fail, st.ops[i].rate * 100);
  Serial.println("===========================================================");
}

// ---------- servidor web ----------
void handleRoot() {
  server.send_P(200, "text/html; charset=utf-8", DASHBOARD_HTML);
}

void handleApi() {
  JsonDocument doc;
  doc["overall"]   = st.overall;
  doc["httpCode"]  = st.httpCode;
  doc["error"]     = st.error;
  doc["pollMs"]    = st.pollMs;
  doc["polls"]     = st.polls;
  doc["failures"]  = st.failures;
  doc["ageSec"]    = st.lastPoll ? (millis() - st.lastPoll) / 1000 : -1;
  doc["uptimeSec"] = millis() / 1000;
  doc["rssi"]      = WiFi.RSSI();
  doc["ip"]        = WiFi.localIP().toString();
  doc["ssid"]      = WiFi.SSID();
  doc["heap"]      = ESP.getFreeHeap();
  doc["pollEvery"] = POLL_MS / 1000;

  JsonArray checks = doc["checks"].to<JsonArray>();
  for (int i = 0; i < st.nChecks; i++) {
    JsonObject c = checks.add<JsonObject>();
    c["name"] = st.checks[i].name; c["status"] = st.checks[i].status; c["latencyMs"] = st.checks[i].latencyMs;
  }
  JsonArray ops = doc["operations"].to<JsonArray>();
  for (int i = 0; i < st.nOps; i++) {
    JsonObject o = ops.add<JsonObject>();
    o["name"] = st.ops[i].name; o["status"] = st.ops[i].status;
    o["ok"] = st.ops[i].ok; o["fail"] = st.ops[i].fail; o["rate"] = st.ops[i].rate;
  }

  String out;
  serializeJson(doc, out);
  server.sendHeader("Cache-Control", "no-store");
  server.send(200, "application/json", out);
}

void handleRefresh() {      // POST /refresh força uma consulta imediata
  runPoll();
  server.sendHeader("Location", "/");
  server.send(303);
}

void runPoll() {
  st.polls++;
  bool ok = pollHealth();
  st.lastPoll = millis();
  if (ok) st.lastOk = millis(); else st.failures++;
  printSerialDashboard();
  displayFull(st);
}

// ---------- ciclo de vida ----------
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println("\n\n=== esp32-painel ===");

  displayBegin();
  displayMessage("esp32-painel", (String("conectando em ") + WIFI_SSID).c_str());
  connectWifi();
  displayMessage("esp32-painel", WiFi.status() == WL_CONNECTED ? "consultando usestl.com/health..." : "wifi falhou, tentando de novo");

  if (MDNS.begin(MDNS_NAME)) {
    MDNS.addService("http", "tcp", 80);
    Serial.printf("[mdns] http://%s.local/\n", MDNS_NAME);
  }

  server.on("/",        HTTP_GET,  handleRoot);
  server.on("/api",     HTTP_GET,  handleApi);
  server.on("/refresh", HTTP_POST, handleRefresh);
  server.onNotFound([]{ server.send(404, "text/plain", "404"); });
  server.begin();
  Serial.printf("[web]  http://%s/\n", WiFi.localIP().toString().c_str());

  runPoll();
}

void loop() {
  static uint32_t lastPoll = millis();
  static uint32_t lastWifiCheck = 0;

  server.handleClient();
  updateLed();

  static uint32_t lastFooter = 0;
  if (millis() - lastFooter >= 1000) { lastFooter = millis(); drawFooter(st, WiFi.status() == WL_CONNECTED); }

  if (touchTapped()) {            // toque na tela = consulta imediata
    Serial.println("[touch] atualizando");
    drawFooter(st, true);
    lastPoll = millis();
    runPoll();
  }

  if (WiFi.status() != WL_CONNECTED && millis() - lastWifiCheck > 10000) {
    lastWifiCheck = millis();
    Serial.println("[wifi] caiu, reconectando...");
    WiFi.disconnect();
    connectWifi();
  }

  if (millis() - lastPoll >= POLL_MS) {
    lastPoll = millis();
    runPoll();
  }
  delay(5);
}
