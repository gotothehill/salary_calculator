import 'dart:ui';

import 'package:flutter/material.dart';

import 'calculators.dart';
import 'i18n.dart';
import 'widgets.dart';

enum Country { china, japan }

void main() {
  runApp(const SalaryApp());
}

class _MonthControllers {
  _MonthControllers({
    required this.salary,
    required this.socialBase,
    required this.fundBase,
    required this.extraDeduction,
  });

  final TextEditingController salary;
  final TextEditingController socialBase;
  final TextEditingController fundBase;
  final TextEditingController extraDeduction;

  void dispose() {
    salary.dispose();
    socialBase.dispose();
    fundBase.dispose();
    extraDeduction.dispose();
  }
}

class SalaryApp extends StatelessWidget {
  const SalaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '工资计算器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SalaryCalculatorPage(),
    );
  }
}

class SalaryCalculatorPage extends StatefulWidget {
  const SalaryCalculatorPage({super.key});

  @override
  State<SalaryCalculatorPage> createState() => _SalaryCalculatorPageState();
}

class _SalaryCalculatorPageState extends State<SalaryCalculatorPage> {
  final _salaryController = TextEditingController(text: '15000');
  final _socialBaseController = TextEditingController(text: '15000');
  final _fundBaseController = TextEditingController(text: '15000');
  final _pensionRateController = TextEditingController(text: '8');
  final _medicalRateController = TextEditingController(text: '2');
  final _unemploymentRateController = TextEditingController(text: '0.5');
  final _housingFundRateController = TextEditingController(text: '12');
  final _standardDeductionController = TextEditingController(text: '5000');
  final _extraDeductionController = TextEditingController(text: '0');
  final _jpAnnualSalaryController = TextEditingController(text: '6000000');
  final _jpAgeController = TextEditingController(text: '30');
  final _jpDependentsController = TextEditingController(text: '0');

  late final List<_MonthControllers> _monthControllers;
  bool _useCumulative = false;
  int _calcToMonth = DateTime.now().month;
  bool _monthsExpanded = true;
  Country _country = Country.china;
  bool _jpHasSpouse = false;
  bool _jpIsFirstYear = true;
  AppLocale _locale = AppLocale.zh;

  double _gross = 0;
  double _taxableIncome = 0;
  double _tax = 0;
  double _net = 0;
  double _cumulativeTax = 0;
  double _cumulativeTaxable = 0;
  double _residentTax = 0;

  double _pension = 0;
  double _medical = 0;
  double _unemployment = 0;
  double _housingFund = 0;

  @override
  void initState() {
    super.initState();
    _salaryController.addListener(_syncSalaryToBases);
    _monthControllers = List.generate(
      12,
      (index) => _MonthControllers(
        salary: TextEditingController(text: _salaryController.text),
        socialBase: TextEditingController(text: _socialBaseController.text),
        fundBase: TextEditingController(text: _fundBaseController.text),
        extraDeduction: TextEditingController(text: '0'),
      ),
    );
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _socialBaseController.dispose();
    _fundBaseController.dispose();
    _pensionRateController.dispose();
    _medicalRateController.dispose();
    _unemploymentRateController.dispose();
    _housingFundRateController.dispose();
    _standardDeductionController.dispose();
    _extraDeductionController.dispose();
    _jpAnnualSalaryController.dispose();
    _jpAgeController.dispose();
    _jpDependentsController.dispose();
    for (final month in _monthControllers) {
      month.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    if (_country == Country.japan) {
      _calculateJapan();
    } else {
      _calculateChina();
    }
  }

  void _calculateChina() {
    final salary = _parse(_salaryController.text, 0);
    final socialBase = _parse(_socialBaseController.text, salary);
    final fundBase = _parse(_fundBaseController.text, socialBase);

    final params = ChinaCalcParams(
      salary: salary,
      socialBase: socialBase,
      fundBase: fundBase,
      pensionRate: _parse(_pensionRateController.text, 8) / 100,
      medicalRate: _parse(_medicalRateController.text, 2) / 100,
      unemploymentRate: _parse(_unemploymentRateController.text, 0.5) / 100,
      housingFundRate: _parse(_housingFundRateController.text, 12) / 100,
      standardDeduction: _parse(_standardDeductionController.text, 5000),
      extraDeduction: _parse(_extraDeductionController.text, 0),
      useCumulative: _useCumulative,
      targetMonth: _calcToMonth,
      months: List.generate(
        12,
        (i) => MonthValue(
          salary: _parse(_monthControllers[i].salary.text, salary),
          socialBase: _parse(_monthControllers[i].socialBase.text, socialBase),
          fundBase: _parse(_monthControllers[i].fundBase.text, fundBase),
          extra: _parse(_monthControllers[i].extraDeduction.text, 0),
        ),
      ),
    );

    final result = calcChina(params);
    setState(() {
      _gross = result.gross;
      _pension = result.pension;
      _medical = result.medical;
      _unemployment = result.unemployment;
      _housingFund = result.housing;
      _taxableIncome = result.taxable;
      _tax = result.tax;
      _net = result.net;
      _cumulativeTax = result.cumulativeTax;
      _cumulativeTaxable = result.cumulativeTaxable;
      _residentTax = result.residentTax;
    });
  }

  void _calculateJapan() {
    final params = JapanCalcParams(
      grossAnnual: _parse(_jpAnnualSalaryController.text, 0),
      age: _parse(_jpAgeController.text, 30).round(),
      dependents: _parse(_jpDependentsController.text, 0).round(),
      hasSpouse: _jpHasSpouse,
      isFirstYear: _jpIsFirstYear,
    );

    final result = calcJapan(params);
    setState(() {
      _gross = result.gross;
      _pension = result.pension;
      _medical = result.medical;
      _unemployment = result.unemployment;
      _housingFund = result.housing;
      _taxableIncome = result.taxable;
      _tax = result.tax;
      _net = result.net;
      _cumulativeTax = result.cumulativeTax;
      _cumulativeTaxable = result.cumulativeTaxable;
      _residentTax = result.residentTax;
    });
  }

  void _resetResults() {
    setState(() {
      _gross = 0;
      _pension = 0;
      _medical = 0;
      _unemployment = 0;
      _housingFund = 0;
      _taxableIncome = 0;
      _tax = 0;
      _net = 0;
      _cumulativeTax = 0;
      _cumulativeTaxable = 0;
      _residentTax = 0;
    });
  }

  void _fillMonthsFromTop() {
    final salaryText = _salaryController.text;
    final socialText = _socialBaseController.text;
    final fundText = _fundBaseController.text;
    final extraText = _extraDeductionController.text;

    for (final month in _monthControllers) {
      month.salary.text = salaryText;
      month.socialBase.text = socialText;
      month.fundBase.text = fundText;
      month.extraDeduction.text = extraText;
    }
    setState(() {});
  }

  void _syncSalaryToBases() {
    final salaryText = _salaryController.text;
    _socialBaseController.text = salaryText;
    _fundBaseController.text = salaryText;
  }

  void _onMonthSalaryChanged(int index, String value) {
    if (index < 0 || index >= _monthControllers.length) return;
    final month = _monthControllers[index];
    month.socialBase.text = value;
    month.fundBase.text = value;
  }

  double _parse(String value, double fallback) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? fallback;
  }

  String _format(double value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final strings = Strings(_locale);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F4),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          strings.t('app_title'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double horizontalPadding = 16;
            final double rawWidth = constraints.maxWidth - horizontalPadding * 2;
            final double contentWidth = rawWidth < 320 ? 320 : rawWidth;
            final double fieldWidth = contentWidth;
            final totalInsurance = _pension + _medical + _unemployment + _housingFund;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: contentWidth,
                      child: SectionCard(
                        title: strings.t('country'),
                        children: [
                          Row(
                            children: [
                              DropdownButton<Country>(
                                value: _country,
                                items: [
                                  DropdownMenuItem(
                                    value: Country.china,
                                    child: Text(strings.t('china')),
                                  ),
                                  DropdownMenuItem(
                                    value: Country.japan,
                                    child: Text(strings.t('japan')),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _country = v;
                                    _useCumulative = _country == Country.china && _useCumulative;
                                    _resetResults();
                                  });
                                },
                              ),
                              const SizedBox(width: 16),
                              DropdownButton<AppLocale>(
                                value: _locale,
                                items: const [
                                  DropdownMenuItem(
                                    value: AppLocale.zh,
                                    child: Text('中文'),
                                  ),
                                  DropdownMenuItem(
                                    value: AppLocale.en,
                                    child: Text('English'),
                                  ),
                                  DropdownMenuItem(
                                    value: AppLocale.jp,
                                    child: Text('日本語'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _locale = v);
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_country == Country.china) ...[
                      SizedBox(
                        width: contentWidth,
                        child: SectionCard(
                          title: strings.t('mode'),
                          children: [
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment(value: false, label: Text(strings.t('monthly'))),
                                ButtonSegment(value: true, label: Text(strings.t('cumulative'))),
                              ],
                              selected: {_useCumulative},
                              onSelectionChanged: (value) {
                                setState(() {
                                  _useCumulative = value.first;
                                });
                                if (value.first) {
                                  _fillMonthsFromTop();
                                }
                              },
                            ),
                            if (_useCumulative) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(strings.t('calc_to_month')),
                                  const SizedBox(width: 12),
                                  DropdownButton<int>(
                                    value: _calcToMonth,
                                  items: List.generate(
                                    12,
                                    (index) => DropdownMenuItem(
                                      value: index + 1,
                                      child: Text(_locale == AppLocale.zh
                                          ? '${index + 1}月'
                                          : 'Month ${index + 1}'),
                                    ),
                                  ),
                                    onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _calcToMonth = v);
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    strings.t('cumulative_tip'),
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: contentWidth,
                        child: SectionCard(
                          title: strings.t('income_basis'),
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _fieldBox(
                                  LabeledNumberField(
                                    label: strings.t('salary_monthly'),
                                    controller: _salaryController,
                                    suffix: '元',
                                  ),
                                  fieldWidth,
                                ),
                                _fieldBox(
                                  LabeledNumberField(
                                    label: strings.t('social_base'),
                                    controller: _socialBaseController,
                                    suffix: '元',
                                  ),
                                  fieldWidth,
                                ),
                                _fieldBox(
                                  LabeledNumberField(
                                    label: strings.t('fund_base'),
                                    controller: _fundBaseController,
                                    suffix: '元',
                                  ),
                                  fieldWidth,
                                ),
                                if (_useCumulative)
                                  _fieldBox(
                                    LabeledNumberField(
                                      label: strings.t('extra_fill'),
                                      controller: _extraDeductionController,
                                      suffix: '元',
                                      helper: strings.t('extra_fill_help'),
                                    ),
                                    fieldWidth,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_useCumulative)
                        SizedBox(
                          width: contentWidth,
                        child: SectionCard(
                          title: strings.t('monthly_detail'),
                          children: [
                            Text(
                              strings.t('monthly_tip'),
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: _fillMonthsFromTop,
                                  child: Text(strings.t('fill_all')),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _monthsExpanded = !_monthsExpanded;
                                    });
                                  },
                                  icon: Icon(_monthsExpanded ? Icons.expand_less : Icons.expand_more),
                                  label: Text(_monthsExpanded
                                      ? strings.t('collapse')
                                      : strings.t('expand')),
                                ),
                              ],
                            ),
                              if (_monthsExpanded) ...[
                                const SizedBox(height: 12),
                                ...List.generate(
                                  _calcToMonth,
                                  (index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _monthRow(index, contentWidth),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (_useCumulative) const SizedBox(height: 12),
                      SizedBox(
                        width: contentWidth,
                        child: SectionCard(
                          title: strings.t('personal_ratio'),
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _fieldBox(
                                  LabeledNumberField(
                                    label: strings.t('pension'),
                                    controller: _pensionRateController,
                                    suffix: '%',
                                  ),
                                  fieldWidth,
                                ),
                                _fieldBox(
                                  LabeledNumberField(
                                    label: strings.t('medical'),
                                    controller: _medicalRateController,
                                    suffix: '%',
                                  ),
                                  fieldWidth,
                                ),
                                _fieldBox(
                                  LabeledNumberField(
                                    label: strings.t('unemployment'),
                                    controller: _unemploymentRateController,
                                    suffix: '%',
                                  ),
                                  fieldWidth,
                                ),
                                _fieldBox(
                                  LabeledNumberField(
                                    label: strings.t('housing'),
                                    controller: _housingFundRateController,
                                    suffix: '%',
                                  ),
                                  fieldWidth,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: contentWidth,
                        child: SectionCard(
                          title: strings.t('deduction'),
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _fieldBox(
                                  LabeledNumberField(
                                    label: strings.t('standard'),
                                    controller: _standardDeductionController,
                                    suffix: '元',
                                  ),
                                  fieldWidth,
                                ),
                                if (!_useCumulative)
                                  _fieldBox(
                                    LabeledNumberField(
                                      label: strings.t('extra'),
                                      controller: _extraDeductionController,
                                      suffix: '元',
                                      helper: strings.t('extra_help'),
                                    ),
                                    fieldWidth,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: contentWidth,
                        child: SectionCard(
                          title: strings.t('jpn_basic'),
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _fieldBox(
                                  LabeledNumberField(
                                    label: strings.t('jpn_income'),
                                    controller: _jpAnnualSalaryController,
                                    suffix: '¥',
                                  ),
                                  fieldWidth,
                                ),
                                _fieldBox(
                                  LabeledNumberField(
                                    label: strings.t('age'),
                                    controller: _jpAgeController,
                                    suffix: '',
                                  ),
                                  fieldWidth,
                                ),
                                _fieldBox(
                                  LabeledNumberField(
                                    label: strings.t('dependents'),
                                    controller: _jpDependentsController,
                                  ),
                                  fieldWidth,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilterChip(
                                  label: Text(strings.t('spouse')),
                                  selected: _jpHasSpouse,
                                  onSelected: (v) => setState(() => _jpHasSpouse = v),
                                ),
                                FilterChip(
                                  label: Text(strings.t('first_year')),
                                  selected: _jpIsFirstYear,
                                  onSelected: (v) => setState(() => _jpIsFirstYear = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              strings.t('jpn_note'),
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: contentWidth,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: () {
                          _calculate();
                        },
                        icon: const Icon(Icons.calculate),
                        label: Text(strings.t('calculate')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: contentWidth,
                      child: SectionCard(
                        title: strings.t('result'),
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _fieldBox(
                                StatCard(
                                  label: _country == Country.china
                                      ? (_useCumulative
                                          ? strings.t('net_month')
                                          : strings.t('net'))
                                      : strings.t('net_year'),
                                  value: _formatCurrency(_net),
                                  color: colorScheme.primary,
                                ),
                                fieldWidth,
                              ),
                              _fieldBox(
                                StatCard(
                                  label: _country == Country.china
                                      ? (_useCumulative
                                          ? strings.t('tax_month')
                                          : strings.t('tax'))
                                      : strings.t('income_tax'),
                                  value: _formatCurrency(_tax),
                                  color: Colors.deepOrange,
                                ),
                                fieldWidth,
                              ),
                              _fieldBox(
                                StatCard(
                                  label: _country == Country.china
                                      ? strings.t('insurance_total')
                                      : strings.t('insurance_total'),
                                  value: _formatCurrency(totalInsurance),
                                  color: Colors.teal,
                                ),
                                fieldWidth,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          ResultTile(
                            label: _country == Country.china
                                ? (_useCumulative ? strings.t('gross_month') : strings.t('gross'))
                                : strings.t('jpn_income'),
                            value: _format(_gross),
                          ),
                          ResultTile(
                            label: _country == Country.china
                                ? strings.t('pension')
                                : strings.t('pension_jp'),
                            value: _format(_pension),
                          ),
                          ResultTile(
                            label: _country == Country.china
                                ? strings.t('medical')
                                : strings.t('health_jp'),
                            value: _format(_medical),
                          ),
                          ResultTile(
                            label: _country == Country.china
                                ? strings.t('unemployment')
                                : strings.t('employment_jp'),
                            value: _format(_unemployment),
                          ),
                          ResultTile(
                            label: _country == Country.china
                                ? strings.t('housing')
                                : strings.t('care_jp'),
                            value: _format(_housingFund),
                          ),
                          if (_country == Country.china && _useCumulative)
                            ResultTile(
                              label: strings.t('cumulative_taxable'),
                              value: _format(_cumulativeTaxable),
                            ),
                          ResultTile(
                            label: _country == Country.china
                                ? (_useCumulative ? strings.t('taxable_month') : strings.t('taxable'))
                                : strings.t('taxable'),
                            value: _format(_taxableIncome),
                          ),
                          if (_country == Country.china && _useCumulative)
                            ResultTile(
                              label: strings.t('cumulative_tax'),
                              value: _format(_cumulativeTax),
                            ),
                          if (_country == Country.japan)
                            ResultTile(
                              label: strings.t('resident_tax'),
                              value: _format(_residentTax),
                            ),
                          ResultTile(
                            label: _country == Country.china
                                ? (_useCumulative ? strings.t('tax_month') : strings.t('tax'))
                                : strings.t('income_tax'),
                            value: _format(_tax),
                          ),
                          ResultTile(
                            label: _country == Country.china
                                ? (_useCumulative ? strings.t('net_month') : strings.t('net'))
                                : strings.t('net_year'),
                            value: _format(_net),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _monthRow(int index, double contentWidth) {
    final data = _monthControllers[index];
    final strings = Strings(_locale);
    final isWide = contentWidth > 640;
    final fieldWidth = isWide ? (contentWidth - 12) / 2 : contentWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _locale == AppLocale.zh ? '${index + 1}月' : 'Month ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _fieldBox(
              LabeledNumberField(
                label: strings.t('month_income'),
                controller: data.salary,
                suffix: _locale == AppLocale.zh ? '元' : '',
                onChanged: (v) => _onMonthSalaryChanged(index, v),
              ),
              fieldWidth,
            ),
            _fieldBox(
              LabeledNumberField(
                label: strings.t('month_social_base'),
                controller: data.socialBase,
                suffix: _locale == AppLocale.zh ? '元' : '',
              ),
              fieldWidth,
            ),
            _fieldBox(
              LabeledNumberField(
                label: strings.t('month_fund_base'),
                controller: data.fundBase,
                suffix: _locale == AppLocale.zh ? '元' : '',
              ),
              fieldWidth,
            ),
            _fieldBox(
              LabeledNumberField(
                label: strings.t('month_extra'),
                controller: data.extraDeduction,
                suffix: _locale == AppLocale.zh ? '元' : '',
              ),
              fieldWidth,
            ),
          ],
        ),
      ],
    );
  }
  Widget _fieldBox(Widget child, double width) {
    return SizedBox(width: width, child: child);
  }

  String _formatCurrency(double value) => '¥${_format(value)}';
}
