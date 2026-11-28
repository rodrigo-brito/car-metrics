import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/vehicle_controller.dart';
import '../theme.dart';
import '../widgets/alert_overlay.dart';
import '../widgets/screen_scale.dart';
import '../widgets/status_bar.dart';
import 'diag_page.dart';
import 'drive_page.dart';
import 'engine_page.dart';
import 'incline_page.dart';

/// As quatro páginas do painel (deslize ou toque nas abas), barra de status e alertas.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});
  final VehicleController controller;

  static const pageNames = ['DIRIGIR', 'MOTOR', 'DIAGNÓSTICO', 'INCLINAÇÃO'];

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final PageController _pc = PageController(initialPage: widget.controller.page);

  bool? _immersive;

  /// Mantém o PageView (e a página atual) quando o layout muda de retrato para paisagem.
  final GlobalKey _pagesKey = GlobalKey();

  /// Em paisagem esconde as barras do Android para os indicadores caberem sem rolar.
  void _setImmersive(bool on) {
    if (_immersive == on) return;
    _immersive = on;
    SystemChrome.setEnabledSystemUIMode(on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    if (_immersive == true) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) c.stop();
      },
      child: Scaffold(
        body: SafeArea(
          // em tablet tudo é ampliado na mesma proporção, para aproveitar a tela
          child: ScreenScale(
            // fonte do sistema muito aumentada desmontaria o painel; acima de 1,3× para aqui
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) {
                  final alert = c.alert;
                  final size = MediaQuery.sizeOf(context);
                  final landscape = size.width > size.height;
                  _setImmersive(landscape);
                  final status = StatusBar(
                    controller: c,
                    pageName: landscape ? '' : DashboardScreen.pageNames[c.page],
                    onDisconnect: () => Navigator.of(context).maybePop(),
                  );
                  final pages = PageView(
                    key: _pagesKey,
                    controller: _pc,
                    onPageChanged: c.goToPage,
                    children: [
                      DrivePage(controller: c),
                      EnginePage(controller: c),
                      DiagPage(controller: c),
                      const InclinePage(),
                    ],
                  );
                  final tabs = _PageTabs(
                    atTop: landscape,
                    names: DashboardScreen.pageNames,
                    current: c.page,
                    onTap: (i) => _pc.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                  );
                  return Stack(
                    children: [
                      Column(
                        children: [
                          if (landscape)
                            // paisagem: status e abas na mesma linha, para sobrar altura
                            SizedBox(
                              height: 44,
                              child: Row(
                                children: [
                                  Expanded(flex: 9, child: status),
                                  Expanded(flex: 11, child: tabs),
                                ],
                              ),
                            )
                          else
                            status,
                          Expanded(child: pages),
                          if (!landscape) tabs,
                        ],
                      ),
                      if (alert != null) Positioned.fill(child: AlertOverlay(alert: alert, onDismiss: c.dismissAlert)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageTabs extends StatelessWidget {
  const _PageTabs({required this.names, required this.current, required this.onTap, this.atTop = false});

  /// No topo (paisagem) o traço da aba ativa fica embaixo; no rodapé, em cima.
  final bool atTop;
  final List<String> names;
  final int current;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.panel,
      child: Row(
        children: [
          for (var i = 0; i < names.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  decoration: BoxDecoration(
                    border: atTop
                        ? Border(bottom: BorderSide(color: i == current ? Palette.accent : Palette.panel, width: 2))
                        : Border(top: BorderSide(color: i == current ? Palette.accent : Palette.panel, width: 2)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      names[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: i == current ? Palette.txt : Palette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
