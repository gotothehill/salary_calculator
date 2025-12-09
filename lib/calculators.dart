class CalcResult {
  const CalcResult({
    required this.gross,
    required this.pension,
    required this.medical,
    required this.unemployment,
    required this.housing,
    required this.taxable,
    required this.tax,
    required this.net,
    required this.cumulativeTax,
    required this.cumulativeTaxable,
    required this.residentTax,
  });

  final double gross;
  final double pension;
  final double medical;
  final double unemployment;
  final double housing;
  final double taxable;
  final double tax;
  final double net;
  final double cumulativeTax;
  final double cumulativeTaxable;
  final double residentTax;
}

class MonthValue {
  const MonthValue({
    required this.salary,
    required this.socialBase,
    required this.fundBase,
    required this.extra,
  });

  final double salary;
  final double socialBase;
  final double fundBase;
  final double extra;
}

class ChinaCalcParams {
  ChinaCalcParams({
    required this.salary,
    required this.socialBase,
    required this.fundBase,
    required this.pensionRate,
    required this.medicalRate,
    required this.unemploymentRate,
    required this.housingFundRate,
    required this.standardDeduction,
    required this.extraDeduction,
    required this.useCumulative,
    required this.targetMonth,
    required this.months,
  });

  final double salary;
  final double socialBase;
  final double fundBase;
  final double pensionRate;
  final double medicalRate;
  final double unemploymentRate;
  final double housingFundRate;
  final double standardDeduction;
  final double extraDeduction;
  final bool useCumulative;
  final int targetMonth;
  final List<MonthValue> months;
}

class JapanCalcParams {
  JapanCalcParams({
    required this.grossAnnual,
    required this.age,
    required this.dependents,
    required this.hasSpouse,
    required this.isFirstYear,
  });

  final double grossAnnual;
  final int age;
  final int dependents;
  final bool hasSpouse;
  final bool isFirstYear;
}

CalcResult calcChina(ChinaCalcParams p) {
  if (!p.useCumulative) {
    final pension = p.socialBase * p.pensionRate;
    final medical = p.socialBase * p.medicalRate;
    final unemployment = p.socialBase * p.unemploymentRate;
    final housingFund = p.fundBase * p.housingFundRate;
    final insuranceTotal = pension + medical + unemployment + housingFund;

    double taxable = p.salary - insuranceTotal - p.standardDeduction - p.extraDeduction;
    if (taxable < 0) taxable = 0;
    final tax = _round2(_calcChinaTax(taxable, cumulative: false));
    final net = p.salary - insuranceTotal - tax;

    return CalcResult(
      gross: p.salary,
      pension: pension,
      medical: medical,
      unemployment: unemployment,
      housing: housingFund,
      taxable: taxable,
      tax: tax,
      net: net,
      cumulativeTax: tax,
      cumulativeTaxable: taxable,
      residentTax: 0,
    );
  }

  final targetMonth = p.targetMonth.clamp(1, 12);
  double cumulativeIncome = 0;
  double cumulativeInsurance = 0;
  double cumulativeExtra = 0;
  double cumulativeTaxable = 0;

  double currentSalary = p.salary;
  double currentInsurance = 0;
  double currentPension = 0;
  double currentMedical = 0;
  double currentUnemployment = 0;
  double currentHousingFund = 0;
  double currentMonthTaxable = 0;

  final List<double> cumulativeTaxList = [];

  for (int i = 0; i < targetMonth; i++) {
    final m = p.months.length > i
        ? p.months[i]
        : MonthValue(
            salary: p.salary,
            socialBase: p.socialBase,
            fundBase: p.fundBase,
            extra: p.extraDeduction,
          );

    final mPension = m.socialBase * p.pensionRate;
    final mMedical = m.socialBase * p.medicalRate;
    final mUnemployment = m.socialBase * p.unemploymentRate;
    final mHousingFund = m.fundBase * p.housingFundRate;
    final mInsurance = mPension + mMedical + mUnemployment + mHousingFund;

    cumulativeIncome += m.salary;
    cumulativeInsurance += mInsurance;
    cumulativeExtra += m.extra;

    cumulativeTaxable = cumulativeIncome -
        cumulativeInsurance -
        cumulativeExtra -
        p.standardDeduction * (i + 1);
    if (cumulativeTaxable < 0) cumulativeTaxable = 0;

    final taxTillNow = _round2(_calcChinaTax(cumulativeTaxable, cumulative: true));
    cumulativeTaxList.add(taxTillNow);

    if (i == targetMonth - 1) {
      currentSalary = m.salary;
      currentInsurance = mInsurance;
      currentPension = mPension;
      currentMedical = mMedical;
      currentUnemployment = mUnemployment;
      currentHousingFund = mHousingFund;
      double monthTaxable = m.salary - mInsurance - m.extra - p.standardDeduction;
      if (monthTaxable < 0) monthTaxable = 0;
      currentMonthTaxable = monthTaxable;
    }
  }

  final double cumulativeTax = cumulativeTaxList.isNotEmpty ? cumulativeTaxList.last : 0.0;
  final double prevCumulativeTax =
      cumulativeTaxList.length > 1 ? cumulativeTaxList[cumulativeTaxList.length - 2] : 0.0;
  final double monthTax =
      _round2((cumulativeTax - prevCumulativeTax).clamp(0, double.infinity).toDouble());
  final net = currentSalary - currentInsurance - monthTax;

  return CalcResult(
    gross: currentSalary,
    pension: currentPension,
    medical: currentMedical,
    unemployment: currentUnemployment,
    housing: currentHousingFund,
    taxable: currentMonthTaxable,
    tax: monthTax,
    net: net,
    cumulativeTax: cumulativeTax,
    cumulativeTaxable: cumulativeTaxable,
    residentTax: 0,
  );
}

CalcResult calcJapan(JapanCalcParams p) {
  final monthly = p.grossAnnual / 12;
  final health = _round2((monthly > 1390000 ? 1390000 : monthly) * 0.05 * 12);
  final pension = _round2((monthly > 650000 ? 650000 : monthly) * 0.0915 * 12);
  final employment = _round2(p.grossAnnual * 0.006);
  final care = p.age >= 40 ? _round2(monthly * 0.009 * 12) : 0.0;
  final socialTotal = _round2(health + pension + employment + care);

  final employmentDeduction = _round2(_calcJpEmploymentDeduction(p.grossAnnual));
  final basicDeduction = 480000.0;
  final spouseDeduction = p.hasSpouse && p.grossAnnual < 9000000 ? 380000.0 : 0.0;
  final dependentsDeduction = p.dependents > 0 ? p.dependents * 380000.0 : 0.0;

  double taxableIncome = p.grossAnnual -
      employmentDeduction -
      socialTotal -
      basicDeduction -
      spouseDeduction -
      dependentsDeduction;
  if (taxableIncome < 0) taxableIncome = 0;

  final incomeTaxBase = _calcJpIncomeTax(taxableIncome);
  final incomeTax = _round2(incomeTaxBase * 1.021);
  final residentTax = p.isFirstYear ? 0.0 : _round2(taxableIncome * 0.10 + 5000);

  final net = p.grossAnnual - socialTotal - incomeTax - residentTax;

  return CalcResult(
    gross: p.grossAnnual,
    pension: pension,
    medical: health,
    unemployment: employment,
    housing: care,
    taxable: taxableIncome,
    tax: incomeTax,
    net: net,
    cumulativeTax: incomeTax,
    cumulativeTaxable: taxableIncome,
    residentTax: residentTax,
  );
}

double _calcChinaTax(double taxableIncome, {required bool cumulative}) {
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

double _calcJpEmploymentDeduction(double annualIncome) {
  if (annualIncome <= 1625000) {
    return 550000;
  } else if (annualIncome <= 1800000) {
    return annualIncome * 0.4 - 100000;
  } else if (annualIncome <= 3600000) {
    return annualIncome * 0.3 + 80000;
  } else if (annualIncome <= 6600000) {
    return annualIncome * 0.2 + 440000;
  } else if (annualIncome <= 8500000) {
    return annualIncome * 0.1 + 1100000;
  } else {
    return 1950000;
  }
}

double _calcJpIncomeTax(double taxableIncome) {
  const brackets = <_TaxBracket>[
    _TaxBracket(1949000, 0.05, 0),
    _TaxBracket(3299000, 0.10, 97500),
    _TaxBracket(6949000, 0.20, 427500),
    _TaxBracket(8999000, 0.23, 636000),
    _TaxBracket(17999000, 0.33, 1536000),
    _TaxBracket(39999000, 0.40, 2796000),
    _TaxBracket(double.infinity, 0.45, 4796000),
  ];

  for (final bracket in brackets) {
    if (taxableIncome <= bracket.limit) {
      final tax = taxableIncome * bracket.rate - bracket.quickDeduction;
      return tax < 0 ? 0.0 : tax;
    }
  }
  return 0.0;
}

double _round2(double value) => (value * 100).roundToDouble() / 100;

class _TaxBracket {
  const _TaxBracket(this.limit, this.rate, this.quickDeduction);

  final double limit;
  final double rate;
  final double quickDeduction;
}
