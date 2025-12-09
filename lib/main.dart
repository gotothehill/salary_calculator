import 'dart:ui';

import 'package:flutter/material.dart';

void main() {
  runApp(const SalaryApp());
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

  late final List<_MonthControllers> _monthControllers;
  bool _useCumulative = false;
  int _calcToMonth = DateTime.now().month;
  bool _monthsExpanded = true;

  double _gross = 0;
  double _taxableIncome = 0;
  double _tax = 0;
  double _net = 0;
  double _cumulativeTax = 0;
  double _cumulativeTaxable = 0;

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
    for (final month in _monthControllers) {
      month.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    final salary = _parse(_salaryController.text, 0);
    final socialBase = _parse(_socialBaseController.text, salary);
    final fundBase = _parse(_fundBaseController.text, socialBase);

    final pensionRate = _parse(_pensionRateController.text, 8) / 100;
    final medicalRate = _parse(_medicalRateController.text, 2) / 100;
    final unemploymentRate =
        _parse(_unemploymentRateController.text, 0.5) / 100;
    final housingFundRate =
        _parse(_housingFundRateController.text, 12) / 100;

    final standardDeduction = _parse(_standardDeductionController.text, 5000);
    final extraDeduction = _parse(_extraDeductionController.text, 0);

    if (_useCumulative) {
      final targetMonth = _calcToMonth.clamp(1, 12);
      double cumulativeIncome = 0;
      double cumulativeInsurance = 0;
      double cumulativeExtra = 0;
      double cumulativeTaxable = 0;

      double currentSalary = salary;
      double currentInsurance = 0;
      double currentPension = 0;
      double currentMedical = 0;
      double currentUnemployment = 0;
      double currentHousingFund = 0;
      double currentMonthTaxable = 0;

      final List<double> cumulativeTaxList = [];

      for (int i = 0; i < targetMonth; i++) {
        final data = _monthControllers[i];
        final mSalary = _parse(data.salary.text, salary);
        final mSocial = _parse(data.socialBase.text, mSalary);
        final mFund = _parse(data.fundBase.text, mSocial);
        final mExtra = _parse(data.extraDeduction.text, 0);

        final mPension = mSocial * pensionRate;
        final mMedical = mSocial * medicalRate;
        final mUnemployment = mSocial * unemploymentRate;
        final mHousingFund = mFund * housingFundRate;
        final mInsurance = mPension + mMedical + mUnemployment + mHousingFund;

        cumulativeIncome += mSalary;
        cumulativeInsurance += mInsurance;
        cumulativeExtra += mExtra;

        cumulativeTaxable = cumulativeIncome -
            cumulativeInsurance -
            cumulativeExtra -
            standardDeduction * (i + 1);
        if (cumulativeTaxable < 0) cumulativeTaxable = 0;

        final taxTillNow = _round2(_calcTax(cumulativeTaxable, cumulative: true));
        cumulativeTaxList.add(taxTillNow);

        if (i == targetMonth - 1) {
          currentSalary = mSalary;
          currentInsurance = mInsurance;
          currentPension = mPension;
          currentMedical = mMedical;
          currentUnemployment = mUnemployment;
          currentHousingFund = mHousingFund;
          double monthTaxable = mSalary - mInsurance - mExtra - standardDeduction;
          if (monthTaxable < 0) monthTaxable = 0;
          currentMonthTaxable = monthTaxable;
        }
      }

      final double cumulativeTax = cumulativeTaxList.isNotEmpty ? cumulativeTaxList.last : 0.0;
      final double prevCumulativeTax =
          cumulativeTaxList.length > 1 ? cumulativeTaxList[cumulativeTaxList.length - 2] : 0.0;
      final double monthTax = _round2(
          (cumulativeTax - prevCumulativeTax).clamp(0, double.infinity).toDouble());
      final net = currentSalary - currentInsurance - monthTax;

      setState(() {
        _gross = currentSalary;
        _pension = currentPension;
        _medical = currentMedical;
        _unemployment = currentUnemployment;
        _housingFund = currentHousingFund;
        _taxableIncome = currentMonthTaxable;
        _tax = monthTax;
        _net = net;
        _cumulativeTax = cumulativeTax;
        _cumulativeTaxable = cumulativeTaxable;
      });
    } else {
      final pension = socialBase * pensionRate;
      final medical = socialBase * medicalRate;
      final unemployment = socialBase * unemploymentRate;
      final housingFund = fundBase * housingFundRate;
      final insuranceTotal = pension + medical + unemployment + housingFund;

      double taxableIncome =
          salary - insuranceTotal - standardDeduction - extraDeduction;
      if (taxableIncome < 0) taxableIncome = 0;
      final tax = _round2(_calcTax(taxableIncome, cumulative: false));
      final net = salary - insuranceTotal - tax;

      setState(() {
        _gross = salary;
        _pension = pension;
        _medical = medical;
        _unemployment = unemployment;
        _housingFund = housingFund;
        _taxableIncome = taxableIncome;
        _tax = tax;
        _net = net;
        _cumulativeTax = tax;
        _cumulativeTaxable = taxableIncome;
      });
    }
  }

  double _calcTax(double taxableIncome, {required bool cumulative}) {
    final brackets = cumulative
        ? const <_TaxBracket>[
            _TaxBracket(36000, 0.03, 0),
            _TaxBracket(144000, 0.10, 2520),
            _TaxBracket(300000, 0.20, 16920),
            _TaxBracket(420000, 0.25, 31920),
            _TaxBracket(660000, 0.30, 52920),
            _TaxBracket(960000, 0.35, 85920),
            _TaxBracket(double.infinity, 0.45, 181920),
          ]
        : const <_TaxBracket>[
            _TaxBracket(3000, 0.03, 0),
            _TaxBracket(12000, 0.10, 210),
            _TaxBracket(25000, 0.20, 1410),
            _TaxBracket(35000, 0.25, 2660),
            _TaxBracket(55000, 0.30, 4410),
            _TaxBracket(80000, 0.35, 7160),
            _TaxBracket(double.infinity, 0.45, 15160),
          ];

    for (final bracket in brackets) {
      if (taxableIncome <= bracket.limit) {
        final tax = taxableIncome * bracket.rate - bracket.quickDeduction;
        return tax < 0 ? 0.0 : tax;
      }
    }
    return 0.0;
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

  double _round2(double value) => (value * 100).roundToDouble() / 100;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F4),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          '工资计算器',
          style: TextStyle(fontWeight: FontWeight.w700),
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
                      child: _sectionCard(
                        title: '计算模式',
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: false, label: Text('单月估算')),
                              ButtonSegment(value: true, label: Text('累计预扣（全年）')),
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
                                const Text('计算到月份'),
                                const SizedBox(width: 12),
                                DropdownButton<int>(
                                  value: _calcToMonth,
                                  items: List.generate(
                                    12,
                                    (index) => DropdownMenuItem(
                                      value: index + 1,
                                      child: Text('${index + 1}月'),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _calcToMonth = v);
                                    }
                                  },
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    '累计预扣按当年1月至所选月份的累计收入、专项附加及五险一金计算',
                                    style: TextStyle(fontSize: 12, color: Colors.black54),
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
                      child: _sectionCard(
                        title: '收入与基数',
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _fieldBox(
                                LabeledNumberField(
                                  label: '税前工资 (元/月)',
                                  controller: _salaryController,
                                  suffix: '元',
                                ),
                                fieldWidth,
                              ),
                              _fieldBox(
                                LabeledNumberField(
                                  label: '社保基数 (默认=工资)',
                                  controller: _socialBaseController,
                                  suffix: '元',
                                ),
                                fieldWidth,
                              ),
                              _fieldBox(
                                LabeledNumberField(
                                  label: '公积金基数 (默认=社保基数)',
                                  controller: _fundBaseController,
                                  suffix: '元',
                                ),
                                fieldWidth,
                              ),
                              if (_useCumulative)
                                _fieldBox(
                                  LabeledNumberField(
                                    label: '专项附加/其他扣除 (默认填充月度)',
                                    controller: _extraDeductionController,
                                    suffix: '元',
                                    helper: '用于一键填充月度专项附加',
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
                        child: _sectionCard(
                          title: '月度明细（可覆盖调整）',
                          children: [
                            const Text(
                              '默认使用上方基数/工资，遇到涨薪或专项扣除变化时修改对应月份。',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: _fillMonthsFromTop,
                                  child: const Text('一键填充为上方输入'),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _monthsExpanded = !_monthsExpanded;
                                    });
                                  },
                                  icon: Icon(_monthsExpanded ? Icons.expand_less : Icons.expand_more),
                                  label: Text(_monthsExpanded ? '收起' : '展开'),
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
                      child: _sectionCard(
                        title: '个人缴费比例',
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _fieldBox(
                                LabeledNumberField(
                                  label: '养老',
                                  controller: _pensionRateController,
                                  suffix: '%',
                                ),
                                fieldWidth,
                              ),
                              _fieldBox(
                                LabeledNumberField(
                                  label: '医疗',
                                  controller: _medicalRateController,
                                  suffix: '%',
                                ),
                                fieldWidth,
                              ),
                              _fieldBox(
                                LabeledNumberField(
                                  label: '失业',
                                  controller: _unemploymentRateController,
                                  suffix: '%',
                                ),
                                fieldWidth,
                              ),
                              _fieldBox(
                                LabeledNumberField(
                                  label: '公积金',
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
                      child: _sectionCard(
                        title: '扣除项',
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _fieldBox(
                                LabeledNumberField(
                                  label: '起征额/基础扣除',
                                  controller: _standardDeductionController,
                                  suffix: '元',
                                ),
                                fieldWidth,
                              ),
                              if (!_useCumulative)
                                _fieldBox(
                                  LabeledNumberField(
                                    label: '专项附加/其他扣除',
                                    controller: _extraDeductionController,
                                    suffix: '元',
                                    helper: '如子女教育、住房租金等月度扣除总额',
                                  ),
                                  fieldWidth,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                          label: const Text('开始计算'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: contentWidth,
                      child: _sectionCard(
                        title: '结果',
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _fieldBox(
                                _statCard(
                                  label: _useCumulative ? '本月税后' : '税后工资',
                                  value: _formatCurrency(_net),
                                  color: colorScheme.primary,
                                ),
                                fieldWidth,
                              ),
                              _fieldBox(
                                _statCard(
                                  label: _useCumulative ? '本月应扣个税' : '个税',
                                  value: _formatCurrency(_tax),
                                  color: Colors.deepOrange,
                                ),
                                fieldWidth,
                              ),
                              _fieldBox(
                                _statCard(
                                  label: '五险一金',
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
                          _resultTile(_useCumulative ? '本月税前工资' : '税前工资', _format(_gross)),
                          _resultTile('养老', _format(_pension)),
                          _resultTile('医疗', _format(_medical)),
                          _resultTile('失业', _format(_unemployment)),
                          _resultTile('公积金', _format(_housingFund)),
                          if (_useCumulative)
                            _resultTile('累计应纳税所得额', _format(_cumulativeTaxable)),
                          _resultTile(_useCumulative ? '本月计税收入' : '计税收入', _format(_taxableIncome)),
                          if (_useCumulative)
                            _resultTile('累计应纳税额', _format(_cumulativeTax)),
                          _resultTile(_useCumulative ? '本月应扣个税' : '个税', _format(_tax)),
                          _resultTile(_useCumulative ? '本月税后' : '税后工资', _format(_net)),
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

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 1,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _monthRow(int index, double contentWidth) {
    final data = _monthControllers[index];
    final isWide = contentWidth > 640;
    final fieldWidth = isWide ? (contentWidth - 12) / 2 : contentWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${index + 1}月',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _fieldBox(
              LabeledNumberField(
                label: '税前收入',
                controller: data.salary,
                suffix: '元',
                onChanged: (v) => _onMonthSalaryChanged(index, v),
              ),
              fieldWidth,
            ),
            _fieldBox(
              LabeledNumberField(
                label: '社保基数',
                controller: data.socialBase,
                suffix: '元',
              ),
              fieldWidth,
            ),
            _fieldBox(
              LabeledNumberField(
                label: '公积金基数',
                controller: data.fundBase,
                suffix: '元',
              ),
              fieldWidth,
            ),
            _fieldBox(
              LabeledNumberField(
                label: '专项附加/其他扣除',
                controller: data.extraDeduction,
                suffix: '元',
              ),
              fieldWidth,
            ),
          ],
        ),
      ],
    );
  }

  Widget _resultTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      {required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldBox(Widget child, double width) {
    return SizedBox(width: width, child: child);
  }

  String _formatCurrency(double value) => '¥${_format(value)}';
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

class LabeledNumberField extends StatelessWidget {
  const LabeledNumberField({
    super.key,
    required this.label,
    required this.controller,
    this.suffix,
    this.helper,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? suffix;
  final String? helper;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        suffixText: suffix,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _TaxBracket {
  const _TaxBracket(this.limit, this.rate, this.quickDeduction);

  final double limit;
  final double rate;
  final double quickDeduction;
}
