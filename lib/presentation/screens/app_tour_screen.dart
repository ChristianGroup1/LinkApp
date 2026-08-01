import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/auth_widgets.dart';

class AppTourScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const AppTourScreen({super.key, this.onCompleted});

  static const String tourCompletedKey = 'has_completed_app_tour';

  static Future<bool> isTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(tourCompletedKey) ?? false;
  }

  static Future<void> setTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(tourCompletedKey, true);
  }

  static Future<void> resetTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(tourCompletedKey, false);
  }

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TourStepData> _steps = const [
    TourStepData(
      title: 'مرحباً بك في تطبيق لينك 💒',
      subtitle:
          'منظومتك الرقمية المتكاملة لإدارة كنيستك واجتماعاتك ومتابعة الحضور باحترافية وفخامة عالية.',
      icon: Icons.church_rounded,
      badgeColor: Color(0xFFEFF6FF),
      iconColor: Color(0xFF2563EB),
    ),
    TourStepData(
      title: '١. قسم الاجتماعات 📅',
      subtitle:
          'أدر وتصفح جميع الاجتماعات والفصول التابعة لها واعرف مواعيد الحضور المباشرة.',
      icon: Icons.event_rounded,
      badgeColor: Color(0xFFE0F2FE),
      iconColor: Color(0xFF0284C7),
    ),
    TourStepData(
      title: '٢. سجلات الحضور 📖',
      subtitle:
          'تصفح وراجع كشوفات ومحاضر الحضور السابقة وعدّلها عند الحاجة بسهولة.',
      icon: Icons.history_rounded,
      badgeColor: Color(0xFFEFF6FF),
      iconColor: Color(0xFF2563EB),
    ),
    TourStepData(
      title: '٣. متابعة الغياب 📞',
      subtitle:
          'سجل متابعة وافتقاد الأعضاء الغائبين واحتفظ بتفاصيل التواصل أولاً بأول.',
      icon: Icons.support_agent_rounded,
      badgeColor: Color(0xFFFEF3C7),
      iconColor: Color(0xFFD97706),
    ),
    TourStepData(
      title: '٤. التقارير والإحصائيات 📊',
      subtitle:
          'اعرف نسب حضور كل مخدوم وخادم ومعدلات الالتزام وأيام التسجيل بنظرة واحدة.',
      icon: Icons.analytics_outlined,
      badgeColor: Color(0xFFDCFCE7),
      iconColor: Color(0xFF166534),
    ),
    TourStepData(
      title: '٥. الخدام والصلاحيات 🛡️',
      subtitle:
          'ادع خدام جدد لخدمتك، حدد أدوارهم في المجموعات والفصول، وإدارة صلاحيات الحضور.',
      icon: Icons.admin_panel_settings_outlined,
      badgeColor: Color(0xFFF3E8FF),
      iconColor: Color(0xFF7E22CE),
    ),
  ];

  void _onFinish() async {
    await AppTourScreen.setTourCompleted();
    if (!mounted) return;
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else {
      Navigator.pop(context);
    }
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // Top Header with Skip button & Logo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AuthLogoMark(size: 48),
                    if (_currentPage < _steps.length - 1)
                      TextButton(
                        onPressed: _onFinish,
                        child: Text(
                          'تخطي',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),

              // PageView Slides
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon Badge
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: step.badgeColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: step.iconColor.withValues(alpha: 0.15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                step.icon,
                                size: 64,
                                color: step.iconColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Floating Card with text
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  step.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  step.subtitle,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Navigation bar (Indicators & Next button)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Pager Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _steps.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 28 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Pill Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.35),
                        ),
                        child: Text(
                          _currentPage == _steps.length - 1
                              ? 'ابدأ الاستخدام الآن 🎉'
                              : 'التالي ➔',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TourStepData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color badgeColor;
  final Color iconColor;

  const TourStepData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeColor,
    required this.iconColor,
  });
}
