import 'dart:async';
import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/transactionFilters.dart';
import 'package:budget/pages/walletDetailsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:budget/pages/addWalletPage.dart';
import "package:budget/struct/throttler.dart";

class AndroidOnly extends StatelessWidget {
  const AndroidOnly({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (getPlatform(ignoreEmulation: true) != PlatformOS.isAndroid)
      return SizedBox.shrink();
    return child;
  }
}

class CheckWidgetLaunch extends StatefulWidget {
  const CheckWidgetLaunch({super.key});

  @override
  State<CheckWidgetLaunch> createState() => _CheckWidgetLaunchState();
}

Throttler widgetActionThrottler =
    Throttler(duration: Duration(milliseconds: 350));

class _CheckWidgetLaunchState extends State<CheckWidgetLaunch> {
  @override
  void initState() {
    super.initState();
    HomeWidget.setAppGroupId('WIDGET_GROUP_ID');
    Future.delayed(Duration(milliseconds: 50), () {
      _checkForWidgetLaunch();
    });
    HomeWidget.widgetClicked.listen(_launchedFromWidget);
  }

  void _checkForWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
  }

  // For some reason, older Android versions open an entirely new app instance... weird!
  // has this been fixed with: android:launchMode="singleInstance" ?
  void _launchedFromWidget(Uri? uri) async {
    // Only perform one widget action per launch/continue of the app
    if (!widgetActionThrottler.canProceed()) return;

    String widgetPayload = (uri ?? "").toString();
    if (widgetPayload == "addTransactionWidget") {
      // Add a delay so the keyboard can focus
      Future.delayed(Duration(milliseconds: 50), () {
        pushRoute(
          context,
          AddTransactionPage(
            routesToPopAfterDelete: RoutesToPopAfterDelete.None,
          ),
        );
      });
    } else if (widgetPayload == "transferTransactionWidget") {
      // This fixes an issue on older versions of Android where the route would popup twice
      // We can detect when this is going to happen if the Provider is not yet loaded, so just pop
      // the route when this is called so the first time routing does not persist (i.e. we end with one route)
      if (Provider.of<AllWallets>(context, listen: false)
              .indexedByPk[appStateSettings["selectedWalletPk"]] ==
          null) popAllRoutes(context);

      openBottomSheet(
        context,
        fullSnap: true,
        TransferBalancePopup(
          allowEditWallet: true,
          wallet: Provider.of<AllWallets>(context, listen: false)
              .indexedByPk[appStateSettings["selectedWalletPk"]],
          showAllEditDetails: true,
        ),
      );
    } else if (widgetPayload == "netWorthLaunchWidget") {
      pushRoute(
        context,
        WalletDetailsPage(
          wallet: null,
        ),
      );
    } else if (widgetPayload == "accountBalanceLaunchWidget") {
      // Open the wallet details page for the selected account in the widget
      // Uses the stored widget account pk, or falls back to selected wallet
      String? widgetAccountPk = appStateSettings["widgetAccountPk"];
      TransactionWallet? wallet = widgetAccountPk != null
          ? Provider.of<AllWallets>(context, listen: false)
              .indexedByPk[widgetAccountPk]
          : Provider.of<AllWallets>(context, listen: false)
              .indexedByPk[appStateSettings["selectedWalletPk"]];
      pushRoute(
        context,
        WalletDetailsPage(
          wallet: wallet,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.shrink();
  }
}

class RenderHomePageWidgets extends StatefulWidget {
  const RenderHomePageWidgets({super.key});

  @override
  State<RenderHomePageWidgets> createState() => RenderHomePageWidgetsState();
}

Future updateWidgetColorsAndText(BuildContext context) async {
  if (getPlatform(ignoreEmulation: true) != PlatformOS.isAndroid) return;
  await Future.delayed(Duration(milliseconds: 500), () async {
    double widgetBackgroundOpacity =
        (double.tryParse((appStateSettings["widgetOpacity"] ?? 1).toString()) ??
                1)
            .clamp(0, 1);
    ThemeData widgetTheme = appStateSettings["widgetTheme"] == "light"
        ? getLightTheme()
        : appStateSettings["widgetTheme"] == "dark"
            ? getDarkTheme()
            : Theme.of(context);

    await HomeWidget.saveWidgetData<String>('netWorthTitle', "net-worth".tr());
    await HomeWidget.saveWidgetData<String>(
      'widgetColorBackground',
      colorToHex(widgetTheme.colorScheme.secondaryContainer),
    );
    await HomeWidget.saveWidgetData<String>(
      'widgetAlpha',
      widgetTheme.colorScheme.secondaryContainer
          .withOpacity(widgetBackgroundOpacity)
          .alpha
          .toString(),
    );
    await HomeWidget.saveWidgetData<String>(
      'widgetColorPrimary',
      colorToHex(widgetTheme.colorScheme.primary),
    );
    await HomeWidget.saveWidgetData<String>(
      'widgetColorText',
      colorToHex(widgetTheme.colorScheme.onSecondaryContainer),
    );
    await HomeWidget.updateWidget(
      name: 'NetWorthWidgetProvider',
    );
    await HomeWidget.updateWidget(
      name: 'NetWorthPlusWidgetProvider',
    );
    await HomeWidget.updateWidget(
      name: 'PlusWidgetProvider',
    );
    await HomeWidget.updateWidget(
      name: 'TransferWidgetProvider',
    );
    await HomeWidget.updateWidget(
      name: 'AccountBalanceWidgetProvider',
    );
  });

  return;
}

class RenderHomePageWidgetsState extends State<RenderHomePageWidgets> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      updateWidgetColorsAndText(context);
    });
  }

  void refreshState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransactionWallet>>(
      stream: database.getAllPinnedWallets(HomePageWidgetDisplay.NetWorth).$1,
      builder: (context, snapshot) {
        List<String>? walletPks =
            (snapshot.data ?? []).map((item) => item.walletPk).toList();
        if (walletPks.length <= 0 ||
            appStateSettings["netWorthAllWallets"] == true) walletPks = null;
        return Container(
          child: StreamBuilder<TotalWithCount?>(
            stream: database.watchTotalWithCountOfWallet(
              isIncome: null,
              allWallets: Provider.of<AllWallets>(context),
              followCustomPeriodCycle: true,
              cycleSettingsExtension: "NetWorth",
              searchFilters: SearchFilters(walletPks: walletPks ?? []),
            ),
            builder: (context, snapshot) {
              Future.delayed(Duration.zero, () async {
                int totalCount = snapshot.data?.count ?? 0;
                String netWorthTransactionsNumber = totalCount.toString() +
                    " " +
                    (totalCount == 1
                        ? "transaction".tr().toLowerCase()
                        : "transactions".tr().toLowerCase());
                double totalSpent = snapshot.data?.total ?? 0;
                String netWorthAmount = convertToMoney(
                  Provider.of<AllWallets>(context, listen: false),
                  totalSpent,
                );
                await HomeWidget.saveWidgetData<String>(
                  'netWorthAmount',
                  netWorthAmount,
                );
                await HomeWidget.saveWidgetData<String>(
                  'netWorthTransactionsNumber',
                  netWorthTransactionsNumber,
                );
                await HomeWidget.updateWidget(
                  name: 'NetWorthWidgetProvider',
                );
                await HomeWidget.updateWidget(
                  name: 'NetWorthPlusWidgetProvider',
                );
              });

              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}

/// Widget that renders account balance data for the Android home screen widget.
///
/// This widget listens to wallet data changes and updates the AccountBalanceWidget
/// on the Android home screen with the current account name, balance, and currency.
///
/// The widget uses the 'widgetAccountPk' setting to determine which account to display.
/// If not set, it falls back to the currently selected wallet.
class RenderAccountBalanceWidget extends StatefulWidget {
  const RenderAccountBalanceWidget({super.key});

  @override
  State<RenderAccountBalanceWidget> createState() =>
      RenderAccountBalanceWidgetState();
}

class RenderAccountBalanceWidgetState
    extends State<RenderAccountBalanceWidget> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      _updateAccountBalanceWidgetData(null);
    });
  }

  void refreshState() {
    setState(() {});
  }

  /// Resolves the wallet to display in the widget.
  /// Returns null if no wallet is available.
  TransactionWallet? _resolveWidgetWallet(AllWallets allWallets) {
    String? widgetAccountPk = appStateSettings["widgetAccountPk"] ??
        appStateSettings["selectedWalletPk"];

    if (widgetAccountPk == null) return null;

    TransactionWallet? wallet = allWallets.indexedByPk[widgetAccountPk];

    if (wallet == null && allWallets.list.isNotEmpty) {
      // If the widget account is not found, fall back to the first wallet
      wallet = allWallets.list.first;
    }

    return wallet;
  }

  /// Updates the account balance widget with current data.
  /// Takes optional totalWithCount data from the stream.
  Future<void> _updateAccountBalanceWidgetData(TotalWithCount? data) async {
    if (getPlatform(ignoreEmulation: true) != PlatformOS.isAndroid) return;

    AllWallets allWallets = Provider.of<AllWallets>(context, listen: false);
    TransactionWallet? wallet = _resolveWidgetWallet(allWallets);

    if (wallet == null) return;

    double accountBalance = data?.total ?? 0;
    String accountBalanceAmount = convertToMoney(
      allWallets,
      accountBalance,
      currencyKey: wallet.currency,
    );
    String currency = wallet.currency ?? "";

    await HomeWidget.saveWidgetData<String>(
      'accountBalanceAccountName',
      wallet.name,
    );
    await HomeWidget.saveWidgetData<String>(
      'accountBalanceAmount',
      accountBalanceAmount,
    );
    await HomeWidget.saveWidgetData<String>(
      'accountBalanceCurrency',
      currency.isNotEmpty ? currency.toUpperCase() : "account".tr(),
    );
    await HomeWidget.updateWidget(
      name: 'AccountBalanceWidgetProvider',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the selected account pk for the widget, or use the default selected wallet
    String? widgetAccountPk = appStateSettings["widgetAccountPk"] ??
        appStateSettings["selectedWalletPk"];

    if (widgetAccountPk == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<TotalWithCount?>(
      stream: database.watchTotalWithCountOfWallet(
        isIncome: null,
        allWallets: Provider.of<AllWallets>(context),
        searchFilters: SearchFilters(walletPks: [widgetAccountPk]),
      ),
      builder: (context, snapshot) {
        // Use Future.delayed to avoid setState during build
        // This pattern is consistent with RenderHomePageWidgetsState
        Future.delayed(Duration.zero, () async {
          await _updateAccountBalanceWidgetData(snapshot.data);
        });

        return const SizedBox.shrink();
      },
    );
  }
}

