import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/academic_models.dart';
import 'models/grading_scale.dart';
import 'services/app_controller.dart';
import 'services/calculator_service.dart';
import 'services/input_validation_service.dart';
import 'services/local_storage_service.dart';
import 'services/mobile_ads_initializer.dart';
import 'widgets/ad_banner.dart';

const _appName = 'GPA Tracker & Grade Calculator';
const _appIconAsset = 'assets/images/gpa_tracker_icon.png';
const _addSemesterKey = ValueKey('add-semester-button');
const _addCourseKey = ValueKey('add-course-button');
const _addAssignmentKey = ValueKey('add-assignment-button');
const _saveSemesterKey = ValueKey('save-semester-button');
const _saveCourseKey = ValueKey('save-course-button');
const _saveAssignmentKey = ValueKey('save-assignment-button');

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _installGlobalErrorLogging();

      final controller = AppController(LocalStorageService());
      try {
        await controller.load();
      } catch (error, stackTrace) {
        _logStartupException(
          'Local storage initialization failed',
          error,
          stackTrace,
        );
      }

      runApp(GpaTrackerApp(controller: controller));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initializeMobileAdsAfterFirstFrame());
      });
    },
    (error, stackTrace) {
      _logStartupException('Uncaught zone exception', error, stackTrace);
    },
  );
}

void _installGlobalErrorLogging() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _logStartupException(
      'Flutter framework exception',
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _logStartupException('Platform dispatcher exception', error, stackTrace);
    return true;
  };
}

Future<void> _initializeMobileAdsAfterFirstFrame() async {
  try {
    await initializeMobileAdsIfSupported();
  } catch (error, stackTrace) {
    _logStartupException('Mobile Ads initialization failed', error, stackTrace);
  }
}

void _logStartupException(String source, Object error, StackTrace stackTrace) {
  // ignore: avoid_print
  print('[$_appName] $source: $error');
  // ignore: avoid_print
  print(stackTrace);
}

class GpaTrackerApp extends StatelessWidget {
  const GpaTrackerApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return MaterialApp(
            title: _appName,
            debugShowCheckedModeBanner: false,
            themeMode: controller.themeMode,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            home: const ShellScreen(),
          );
        },
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF8B5CF6),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: const Color(0xFF8B5CF6),
      secondary: const Color(0xFF38BDF8),
      tertiary: const Color(0xFFFBBF24),
      surface: isDark ? const Color(0xFF090A14) : const Color(0xFFF7F7FC),
      surfaceContainerLowest: isDark
          ? const Color(0xFF0D1020)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: isDark
          ? const Color(0xFF12162A)
          : const Color(0xFFFFFFFF),
      surfaceContainerHighest: isDark
          ? const Color(0xFF1C2140)
          : const Color(0xFFEDEBFA),
    ),
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF090A14)
        : const Color(0xFFF7F7FC),
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark
          ? const Color(0xFF090A14)
          : const Color(0xFFF7F7FC),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: isDark ? const Color(0xFF12162A) : const Color(0xFFFFFFFF),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF0D1020) : const Color(0xFFFFFFFF),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      backgroundColor: isDark
          ? const Color(0xFF0D1020)
          : const Color(0xFFFFFFFF),
    ),
  );
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!.notifier!;
  }
}

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    SemestersScreen(),
    AssignmentsScreen(),
    CalculatorsScreen(),
    SettingsScreen(),
  ];

  static const _titles = [
    'Dashboard',
    'Semesters',
    'Assignments',
    'Calculators',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final nextThemeMode = controller.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(
        title: _AppTitle(title: _titles[_index]),
        actions: [
          IconButton(
            tooltip: controller.themeMode == ThemeMode.dark
                ? 'Use light mode'
                : 'Use dark mode',
            icon: Icon(
              controller.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => controller.setThemeMode(nextThemeMode),
          ),
        ],
      ),
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppBannerAd(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.school_outlined),
                selectedIcon: Icon(Icons.school),
                label: 'Classes',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.calculate_outlined),
                selectedIcon: Icon(Icons.calculate),
                label: 'GPA',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            _appIconAsset,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final activeSemester = controller.activeSemester;
    final cumulative = CalculatorService.cumulativeGpa(
      controller.semesters,
      controller.scalesById,
    );
    final upcoming = _upcomingAssignments(controller).take(5).toList();
    final courses = activeSemester?.courses ?? const <Course>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _DashboardHeader(
          cumulativeGpa: cumulative.gpa,
          activeSemester: activeSemester,
          courseCount: courses.length,
        ),
        const SizedBox(height: 16),
        _QuickActions(activeSemester: activeSemester),
        if (controller.semesters.isEmpty) ...[
          const SizedBox(height: 16),
          _GettingStartedPanel(onLoadExample: () => _loadExampleData(context)),
        ],
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Upcoming deadlines',
          action: IconButton(
            tooltip: 'Add assignment',
            icon: const Icon(Icons.add_task),
            onPressed: () => showAssignmentDialog(context),
          ),
        ),
        if (upcoming.isEmpty)
          const _EmptyState(
            icon: Icons.event_available_outlined,
            title: 'No upcoming deadlines',
            message: 'Assignments you add will appear here.',
          )
        else
          ...upcoming.map(
            (assignment) => _AssignmentTile(assignment: assignment),
          ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Course grades',
          action: IconButton(
            tooltip: 'Add course',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              final semester = controller.activeSemester;
              if (semester == null) {
                _showMessage(context, 'Add a semester before adding courses.');
                return;
              }
              showCourseDialog(context, semesterId: semester.id);
            },
          ),
        ),
        if (activeSemester == null)
          const _EmptyState(
            icon: Icons.school_outlined,
            title: 'Start with a semester',
            message: 'Create Fall 2026, Spring 2027, or any term you need.',
          )
        else if (courses.isEmpty)
          const _EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No courses yet',
            message: 'Add courses and syllabus weights to start tracking.',
          )
        else
          ...courses.map(
            (course) =>
                CourseGradeCard(semesterId: activeSemester.id, course: course),
          ),
      ],
    );
  }
}

class _GettingStartedPanel extends StatelessWidget {
  const _GettingStartedPanel({required this.onLoadExample});

  final VoidCallback onLoadExample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Build your tracker in 3 steps',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const _StepRow(
            number: '1',
            title: 'Create a semester',
            detail: 'Use names like Fall 2026 or Spring 2027.',
          ),
          const _StepRow(
            number: '2',
            title: 'Add courses',
            detail: 'Set credits and pick the grading system.',
          ),
          const _StepRow(
            number: '3',
            title: 'Enter syllabus weights',
            detail: 'Add midterms, homework, projects, and finals.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            label: const Text('Load Example Semester'),
            onPressed: onLoadExample,
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.cumulativeGpa,
    required this.activeSemester,
    required this.courseCount,
  });

  final double? cumulativeGpa;
  final Semester? activeSemester;
  final int courseCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4C1D95), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C1D95).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  _appIconAsset,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _appName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeSemester?.name ?? 'Plan the semester ahead',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Current GPA',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatGpa(cumulativeGpa),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.calendar_month_outlined,
                label: activeSemester?.name ?? 'No active semester',
              ),
              _InfoChip(
                icon: Icons.menu_book_outlined,
                label:
                    '$courseCount active ${courseCount == 1 ? 'course' : 'courses'}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.activeSemester});

  final Semester? activeSemester;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 560
            ? (constraints.maxWidth - 20) / 3
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: itemWidth,
              child: _QuickActionButton(
                key: _addSemesterKey,
                icon: Icons.add,
                label: 'Add Semester',
                detail: 'Start a term',
                onPressed: () => showSemesterDialog(context),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _QuickActionButton(
                key: _addCourseKey,
                icon: Icons.post_add,
                label: 'Add Course',
                detail: activeSemester?.name ?? 'Needs semester',
                onPressed: () {
                  if (activeSemester == null) {
                    _showMessage(
                      context,
                      'Add a semester before adding courses.',
                    );
                    return;
                  }
                  showCourseDialog(context, semesterId: activeSemester!.id);
                },
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _QuickActionButton(
                key: _addAssignmentKey,
                icon: Icons.add_task,
                label: 'Add Assignment',
                detail: 'Track a deadline',
                onPressed: () => showAssignmentDialog(context),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.detail,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF38BDF8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

class SemestersScreen extends StatelessWidget {
  const SemestersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: _addSemesterKey,
            icon: const Icon(Icons.add),
            label: const Text('Add Semester'),
            onPressed: () => showSemesterDialog(context),
          ),
        ),
        const SizedBox(height: 16),
        if (controller.semesters.isEmpty)
          const _EmptyState(
            icon: Icons.school_outlined,
            title: 'No semesters yet',
            message: 'Create a semester, then add courses from each syllabus.',
          )
        else
          ...controller.semesters.map((semester) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded: semester.isActive,
                leading: Icon(
                  semester.isActive
                      ? Icons.star
                      : Icons.calendar_today_outlined,
                ),
                title: Text(semester.name),
                subtitle: Text(
                  semester.isActive
                      ? 'Active semester'
                      : '${semester.courses.length} courses',
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Semester actions',
                  onSelected: (value) async {
                    if (value == 'active') {
                      await controller.setActiveSemester(semester.id);
                    } else if (value == 'edit') {
                      if (context.mounted) {
                        showSemesterDialog(context, semester: semester);
                      }
                    } else if (value == 'delete') {
                      if (!context.mounted) {
                        return;
                      }
                      final confirmed = await _confirmDelete(
                        context,
                        title: 'Delete ${semester.name}?',
                        message:
                            'Courses and assignments in this semester will be removed.',
                      );
                      if (confirmed) {
                        await controller.deleteSemester(semester.id);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'active',
                      child: Text('Set active'),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        key: _addCourseKey,
                        icon: const Icon(Icons.post_add),
                        label: const Text('Add Course'),
                        onPressed: () =>
                            showCourseDialog(context, semesterId: semester.id),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                        onPressed: () =>
                            showSemesterDialog(context, semester: semester),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        onPressed: () async {
                          final confirmed = await _confirmDelete(
                            context,
                            title: 'Delete ${semester.name}?',
                            message:
                                'Courses and assignments in this semester will be removed.',
                          );
                          if (confirmed) {
                            await controller.deleteSemester(semester.id);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!semester.isActive)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.star_outline),
                        label: const Text('Set Active'),
                        onPressed: () =>
                            controller.setActiveSemester(semester.id),
                      ),
                    ),
                  if (semester.courses.isEmpty)
                    const _EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'No courses',
                      message:
                          'Add a class and enter its credits and grade scale.',
                    )
                  else
                    ...semester.courses.map(
                      (course) => _CourseListTile(
                        semesterId: semester.id,
                        course: course,
                      ),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _CourseListTile extends StatelessWidget {
  const _CourseListTile({required this.semesterId, required this.course});

  final String semesterId;
  final Course course;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final scale = controller.data.scaleById(course.gradingScaleId);
    final current = CalculatorService.currentCourseGrade(course.components);
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
        title: Text(course.name),
        subtitle: Text(
          '${_formatCredits(course.credits)} credits • ${scale.name} • '
          '${_formatPercent(current.percent)}',
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Course actions',
          onSelected: (value) async {
            if (value == 'open') {
              _openCourseDetail(context);
            } else if (value == 'edit') {
              showCourseDialog(context, semesterId: semesterId, course: course);
            } else if (value == 'delete') {
              final confirmed = await _confirmDelete(
                context,
                title: 'Delete ${course.name}?',
                message:
                    'This also removes assignments attached to the course.',
              );
              if (confirmed) {
                await controller.deleteCourse(semesterId, course.id);
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'open', child: Text('Open')),
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _openCourseDetail(context),
      ),
    );
  }

  void _openCourseDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CourseDetailScreen(semesterId: semesterId, courseId: course.id),
      ),
    );
  }
}

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({
    super.key,
    required this.semesterId,
    required this.courseId,
  });

  final String semesterId;
  final String courseId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final semester = controller.semesterById(semesterId);
    final course = semester?.courses
        .where((entry) => entry.id == courseId)
        .firstOrNull;

    if (semester == null || course == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Course')),
        body: const Center(child: Text('Course not found.')),
      );
    }

    final scale = controller.data.scaleById(course.gradingScaleId);
    final current = CalculatorService.currentCourseGrade(course.components);
    final finalEstimate = CalculatorService.finalCourseEstimate(
      course.components,
    );
    final assignments =
        controller.assignments
            .where((assignment) => assignment.courseId == course.id)
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Scaffold(
      appBar: AppBar(
        title: Text(course.name),
        actions: [
          IconButton(
            tooltip: 'Edit course',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showCourseDialog(
              context,
              semesterId: semester.id,
              course: course,
            ),
          ),
          IconButton(
            tooltip: 'Delete course',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await _confirmDelete(
                context,
                title: 'Delete ${course.name}?',
                message:
                    'This also removes assignments attached to the course.',
              );
              if (!confirmed || !context.mounted) {
                return;
              }
              await controller.deleteCourse(semester.id, course.id);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _CourseSummaryPanel(
            course: course,
            scale: scale,
            current: current,
            finalEstimate: finalEstimate,
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Syllabus breakdown',
            action: IconButton(
              tooltip: 'Add component',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => showComponentDialog(
                context,
                semesterId: semester.id,
                courseId: course.id,
              ),
            ),
          ),
          _WeightStatusPanel(course: course),
          const SizedBox(height: 10),
          if (course.components.isEmpty)
            _ComponentTemplatePanel(
              onApply: () async {
                await _applyExampleComponents(
                  context,
                  semesterId: semester.id,
                  courseId: course.id,
                );
              },
            )
          else
            ...course.components.map(
              (component) => _ComponentTile(
                semesterId: semester.id,
                courseId: course.id,
                component: component,
              ),
            ),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Course assignments',
            action: IconButton(
              tooltip: 'Add assignment',
              icon: const Icon(Icons.add_task),
              onPressed: () =>
                  showAssignmentDialog(context, courseId: course.id),
            ),
          ),
          if (assignments.isEmpty)
            const _EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No assignments',
              message:
                  'Track due dates here without linking them to grades yet.',
            )
          else
            ...assignments.map(
              (assignment) => _AssignmentTile(assignment: assignment),
            ),
        ],
      ),
    );
  }
}

class _CourseSummaryPanel extends StatelessWidget {
  const _CourseSummaryPanel({
    required this.course,
    required this.scale,
    required this.current,
    required this.finalEstimate,
  });

  final Course course;
  final GradingScale scale;
  final GradeResult current;
  final GradeResult finalEstimate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalWeight = CalculatorService.totalWeight(course.components);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.credit_score_outlined,
                label: '${_formatCredits(course.credits)} credits',
              ),
              _InfoChip(icon: Icons.scale_outlined, label: scale.name),
              _InfoChip(
                icon: Icons.pie_chart_outline,
                label: '${_formatNumber(totalWeight)}% total weight',
              ),
            ],
          ),
          if ((totalWeight - 100).abs() > 0.01) ...[
            const SizedBox(height: 12),
            _WarningBanner(
              message:
                  'Weights add to ${_formatNumber(totalWeight)}%. GPA math still works, but check the syllabus.',
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Current',
                  value: _formatPercent(current.percent),
                  detail: current.percent == null
                      ? 'No scores yet'
                      : scale.labelForPercent(current.percent!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Final estimate',
                  value: _formatPercent(finalEstimate.percent),
                  detail:
                      '${_formatNumber(finalEstimate.scoredWeight)}% scored',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightStatusPanel extends StatelessWidget {
  const _WeightStatusPanel({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalWeight = CalculatorService.totalWeight(course.components);
    final completed = course.components
        .where((component) => component.hasScore)
        .length;
    final remainingWeight = (100 - totalWeight).clamp(-999, 999).toDouble();
    final status = (totalWeight - 100).abs() <= 0.01
        ? 'Syllabus weights are complete.'
        : remainingWeight > 0
        ? '${_formatNumber(remainingWeight)}% still unassigned.'
        : '${_formatNumber(remainingWeight.abs())}% over 100%.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$completed of ${course.components.length} components have scores.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentTemplatePanel extends StatelessWidget {
  const _ComponentTemplatePanel({required this.onApply});

  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.view_list_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Start from a common syllabus',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Midterm 30% • Assignments 30% • Final 40%'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _MiniComponentChip(label: 'Midterm', value: '30%'),
              _MiniComponentChip(label: 'Assignments', value: '30%'),
              _MiniComponentChip(label: 'Final', value: '40%'),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Use This Example'),
            onPressed: onApply,
          ),
        ],
      ),
    );
  }
}

class _MiniComponentChip extends StatelessWidget {
  const _MiniComponentChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ComponentTile extends StatelessWidget {
  const _ComponentTile({
    required this.semesterId,
    required this.courseId,
    required this.component,
  });

  final String semesterId;
  final String courseId;
  final GradeComponent component;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final score = component.hasScore
        ? '${_formatNumber(component.scoreEarned!)}/${_formatNumber(component.scorePossible!)}'
              ' • ${_formatPercent(component.scorePercent)}'
        : 'No score entered';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(component.name),
        subtitle: Text(
          '${_formatNumber(component.weightPercent)}% weight • $score',
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Component actions',
          onSelected: (value) async {
            if (value == 'edit') {
              showComponentDialog(
                context,
                semesterId: semesterId,
                courseId: courseId,
                component: component,
              );
            } else if (value == 'delete') {
              final confirmed = await _confirmDelete(
                context,
                title: 'Delete ${component.name}?',
                message: 'This removes the score and weight from the course.',
              );
              if (confirmed) {
                await controller.deleteComponent(
                  semesterId,
                  courseId,
                  component.id,
                );
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final assignments = [...controller.assignments]
      ..sort((a, b) {
        if (a.completed != b.completed) {
          return a.completed ? 1 : -1;
        }
        return a.dueDate.compareTo(b.dueDate);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: _addAssignmentKey,
            icon: const Icon(Icons.add_task),
            label: const Text('Add Assignment'),
            onPressed: () => showAssignmentDialog(context),
          ),
        ),
        const SizedBox(height: 16),
        if (assignments.isEmpty)
          const _EmptyState(
            icon: Icons.assignment_turned_in_outlined,
            title: 'No assignments yet',
            message: 'Add due dates and mark them complete as you finish.',
          )
        else
          ...assignments.map(
            (assignment) => _AssignmentTile(assignment: assignment),
          ),
      ],
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.assignment});

  final AssignmentItem assignment;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final course = controller.courseById(assignment.courseId);
    final dueLabel = DateFormat('MMM d, y').format(assignment.dueDate);
    final isPastDue =
        !assignment.completed &&
        assignment.dueDate.isBefore(
          DateTime.now().subtract(const Duration(days: 1)),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Checkbox(
          value: assignment.completed,
          onChanged: (value) =>
              controller.toggleAssignment(assignment.id, value ?? false),
        ),
        title: Text(
          assignment.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            decoration: assignment.completed
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        subtitle: Text(
          '${course?.name ?? 'Course removed'} • $dueLabel'
          '${isPastDue ? ' • Past due' : ''}',
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Assignment actions',
          onSelected: (value) async {
            if (value == 'edit') {
              showAssignmentDialog(context, assignment: assignment);
            } else if (value == 'delete') {
              final confirmed = await _confirmDelete(
                context,
                title: 'Delete ${assignment.title}?',
                message: 'This deadline will be removed from your tracker.',
              );
              if (confirmed) {
                await controller.deleteAssignment(assignment.id);
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen> {
  String? _selectedCourseId;
  final _currentGradeController = TextEditingController(text: '85');
  final _completedWeightController = TextEditingController(text: '80');
  final _finalWeightController = TextEditingController(text: '20');
  final _targetGradeController = TextEditingController(text: '90');
  final _plannerCurrentGpaController = TextEditingController();
  final _plannerEarnedCreditsController = TextEditingController();
  final _plannerTargetGpaController = TextEditingController(text: '3.50');
  final _plannerRemainingCreditsController = TextEditingController();

  @override
  void dispose() {
    _currentGradeController.dispose();
    _completedWeightController.dispose();
    _finalWeightController.dispose();
    _targetGradeController.dispose();
    _plannerCurrentGpaController.dispose();
    _plannerEarnedCreditsController.dispose();
    _plannerTargetGpaController.dispose();
    _plannerRemainingCreditsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final allCourses = controller.semesters
        .expand(
          (semester) => semester.courses.map((course) => (semester, course)),
        )
        .toList();
    final selectedEntry = allCourses
        .where((entry) => entry.$2.id == _selectedCourseId)
        .firstOrNull;
    final fallbackEntry = selectedEntry ?? allCourses.firstOrNull;
    final fallbackCourse = fallbackEntry?.$2;
    final selectedCourseId = fallbackCourse?.id;
    if (_selectedCourseId != selectedCourseId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedCourseId = selectedCourseId);
        }
      });
    }

    final activeSemester = controller.activeSemester;
    final semesterGpa = activeSemester == null
        ? const GpaResult(gpa: null, credits: 0, courseCount: 0)
        : CalculatorService.semesterGpa(activeSemester, controller.scalesById);
    final cumulativeGpa = CalculatorService.cumulativeGpa(
      controller.semesters,
      controller.scalesById,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _SectionHeader(title: 'Course calculators'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (allCourses.isEmpty)
                  const _EmptyState(
                    icon: Icons.calculate_outlined,
                    title: 'Add a course first',
                    message:
                        'Course grade calculators will use your syllabus scores.',
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourseId,
                    decoration: const InputDecoration(labelText: 'Course'),
                    items: allCourses
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.$2.id,
                            child: Text('${entry.$2.name} • ${entry.$1.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCourseId = value),
                  ),
                  const SizedBox(height: 12),
                  _SelectedCourseCalculator(
                    course: fallbackCourse!,
                    scale: controller.data.scaleById(
                      fallbackCourse.gradingScaleId,
                    ),
                    onUseForFinalCalculator: _useSelectedCourseForFinal,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _NeededFinalCard(
          currentGradeController: _currentGradeController,
          completedWeightController: _completedWeightController,
          finalWeightController: _finalWeightController,
          targetGradeController: _targetGradeController,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'GPA calculators'),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: activeSemester?.name ?? 'Semester GPA',
                value: _formatGpa(semesterGpa.gpa),
                detail:
                    '${_formatCredits(semesterGpa.credits)} credits counted',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Cumulative GPA',
                value: _formatGpa(cumulativeGpa.gpa),
                detail:
                    '${_formatCredits(cumulativeGpa.credits)} credits counted',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _GraduationPlannerCard(
          currentGpaController: _plannerCurrentGpaController,
          earnedCreditsController: _plannerEarnedCreditsController,
          targetGpaController: _plannerTargetGpaController,
          remainingCreditsController: _plannerRemainingCreditsController,
          fallbackCurrentGpa: cumulativeGpa.gpa,
          fallbackEarnedCredits: cumulativeGpa.credits,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  void _useSelectedCourseForFinal(Course course) {
    final current = CalculatorService.currentCourseGrade(course.components);
    if (current.percent == null) {
      return;
    }
    setState(() {
      _currentGradeController.text = current.percent!.toStringAsFixed(1);
      _completedWeightController.text = current.scoredWeight.toStringAsFixed(1);
      _finalWeightController.text = (100 - current.scoredWeight)
          .clamp(0, 100)
          .toStringAsFixed(1);
    });
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  _appIconAsset,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _appName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Offline planner for courses, grades, GPA, and deadlines.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Appearance',
          icon: Icons.dark_mode_outlined,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.phone_android_outlined),
                label: Text('System'),
              ),
            ],
            selected: {controller.themeMode},
            onSelectionChanged: (selection) =>
                controller.setThemeMode(selection.first),
          ),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          title: 'Sample semester',
          icon: Icons.auto_awesome_motion_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a realistic semester with courses, scores, a final exam, and a deadline.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add_chart_outlined),
                label: const Text('Load Sample Semester'),
                onPressed: () => _loadExampleData(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          title: 'How the app is organized',
          icon: Icons.account_tree_outlined,
          child: const Column(
            children: [
              _WorkflowRow(
                icon: Icons.calendar_month_outlined,
                title: 'Semester',
                detail: 'The term that contains your classes.',
              ),
              _WorkflowRow(
                icon: Icons.menu_book_outlined,
                title: 'Course',
                detail: 'Credits, grading scale, and syllabus breakdown.',
              ),
              _WorkflowRow(
                icon: Icons.percent_outlined,
                title: 'Component',
                detail: 'Midterms, assignments, finals, projects, attendance.',
              ),
              _WorkflowRow(
                icon: Icons.event_note_outlined,
                title: 'Assignment',
                detail: 'Deadline tracker shown on the dashboard.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          title: 'Grading systems',
          icon: Icons.scale_outlined,
          child: Column(
            children: controller.gradingScales
                .map(
                  (scale) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(scale.name),
                    subtitle: Text(scale.system.label),
                    trailing: Text(
                      scale.system == GradingSystem.percentage
                          ? '0-100%'
                          : 'Max ${_formatNumber(scale.maxDisplayValue)}',
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          title: 'Privacy and release setup',
          icon: Icons.privacy_tip_outlined,
          child: const Column(
            children: [
              _WorkflowRow(
                icon: Icons.storage_outlined,
                title: 'Local storage',
                detail:
                    'Semesters, classes, grades, and assignments stay on this device.',
              ),
              _WorkflowRow(
                icon: Icons.lock_outline,
                title: 'Private by design',
                detail:
                    'The app works offline and does not require an account.',
              ),
              _WorkflowRow(
                icon: Icons.ad_units_outlined,
                title: 'Android ads',
                detail:
                    'Banner ads are enabled on Android when AdMob IDs are configured.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WorkflowRow extends StatelessWidget {
  const _WorkflowRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedCourseCalculator extends StatelessWidget {
  const _SelectedCourseCalculator({
    required this.course,
    required this.scale,
    required this.onUseForFinalCalculator,
  });

  final Course course;
  final GradingScale scale;
  final ValueChanged<Course> onUseForFinalCalculator;

  @override
  Widget build(BuildContext context) {
    final current = CalculatorService.currentCourseGrade(course.components);
    final finalEstimate = CalculatorService.finalCourseEstimate(
      course.components,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Current grade',
                value: _formatPercent(current.percent),
                detail: current.percent == null
                    ? 'No scored components'
                    : scale.labelForPercent(current.percent!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Final estimate',
                value: _formatPercent(finalEstimate.percent),
                detail: '${_formatNumber(finalEstimate.scoredWeight)}% scored',
              ),
            ),
          ],
        ),
        if (current.hasWeightWarning) ...[
          const SizedBox(height: 12),
          _WarningBanner(
            message:
                'Weights total ${_formatNumber(current.totalWeight)}%, not 100%.',
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.arrow_downward),
          label: const Text('Use in final calculator'),
          onPressed: current.percent == null
              ? null
              : () => onUseForFinalCalculator(course),
        ),
      ],
    );
  }
}

class _NeededFinalCard extends StatelessWidget {
  const _NeededFinalCard({
    required this.currentGradeController,
    required this.completedWeightController,
    required this.finalWeightController,
    required this.targetGradeController,
    required this.onChanged,
  });

  final TextEditingController currentGradeController;
  final TextEditingController completedWeightController;
  final TextEditingController finalWeightController;
  final TextEditingController targetGradeController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final current = _parseDouble(currentGradeController.text);
    final completedWeight = _parseDouble(completedWeightController.text);
    final finalWeight = _parseDouble(finalWeightController.text);
    final target = _parseDouble(targetGradeController.text);
    final needed =
        current == null ||
            completedWeight == null ||
            finalWeight == null ||
            target == null
        ? null
        : CalculatorService.neededFinalExamScore(
            currentGradePercent: current,
            completedWeightPercent: completedWeight,
            finalWeightPercent: finalWeight,
            targetCourseGradePercent: target,
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What do I need on the final?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _TwoColumnFields(
              children: [
                _NumberField(
                  controller: currentGradeController,
                  label: 'Current grade %',
                  onChanged: onChanged,
                ),
                _NumberField(
                  controller: completedWeightController,
                  label: 'Completed weight %',
                  onChanged: onChanged,
                ),
                _NumberField(
                  controller: finalWeightController,
                  label: 'Final weight %',
                  onChanged: onChanged,
                ),
                _NumberField(
                  controller: targetGradeController,
                  label: 'Target grade %',
                  onChanged: onChanged,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MetricTile(
              label: 'Needed final score',
              value: needed == null ? '--' : '${needed.toStringAsFixed(1)}%',
              detail: _neededFinalDetail(needed),
            ),
          ],
        ),
      ),
    );
  }

  String _neededFinalDetail(double? needed) {
    if (needed == null) {
      return 'Enter valid positive weights';
    }
    if (needed < 0) {
      return 'Target is already secured by current scores';
    }
    if (needed > 100) {
      return 'Above 100%, so the target is not reachable with this final weight';
    }
    return 'Within a normal 0-100% final score range';
  }
}

class _GraduationPlannerCard extends StatelessWidget {
  const _GraduationPlannerCard({
    required this.currentGpaController,
    required this.earnedCreditsController,
    required this.targetGpaController,
    required this.remainingCreditsController,
    required this.fallbackCurrentGpa,
    required this.fallbackEarnedCredits,
    required this.onChanged,
  });

  final TextEditingController currentGpaController;
  final TextEditingController earnedCreditsController;
  final TextEditingController targetGpaController;
  final TextEditingController remainingCreditsController;
  final double? fallbackCurrentGpa;
  final double fallbackEarnedCredits;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final currentGpa =
        _parseDouble(currentGpaController.text) ?? fallbackCurrentGpa;
    final earnedCredits =
        _parseDouble(earnedCreditsController.text) ?? fallbackEarnedCredits;
    final targetGpa = _parseDouble(targetGpaController.text);
    final remainingCredits = _parseDouble(remainingCreditsController.text);
    final required =
        currentGpa == null || targetGpa == null || remainingCredits == null
        ? null
        : CalculatorService.graduationRequiredGpa(
            currentGpa: currentGpa,
            earnedCredits: earnedCredits,
            targetGpa: targetGpa,
            remainingCredits: remainingCredits,
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Graduation GPA planner',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _TwoColumnFields(
              children: [
                _NumberField(
                  controller: currentGpaController,
                  label: 'Current GPA',
                  hint: fallbackCurrentGpa?.toStringAsFixed(2),
                  onChanged: onChanged,
                ),
                _NumberField(
                  controller: earnedCreditsController,
                  label: 'Earned credits',
                  hint: _formatCredits(fallbackEarnedCredits),
                  onChanged: onChanged,
                ),
                _NumberField(
                  controller: targetGpaController,
                  label: 'Target GPA',
                  onChanged: onChanged,
                ),
                _NumberField(
                  controller: remainingCreditsController,
                  label: 'Remaining credits',
                  onChanged: onChanged,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MetricTile(
              label: 'Required future GPA',
              value: _formatGpa(required),
              detail: required == null
                  ? 'Enter target and remaining credits'
                  : required > 4.3
                  ? 'Above a typical 4.3 maximum'
                  : 'Average needed across remaining credits',
            ),
          ],
        ),
      ),
    );
  }
}

class CourseGradeCard extends StatelessWidget {
  const CourseGradeCard({
    super.key,
    required this.semesterId,
    required this.course,
  });

  final String semesterId;
  final Course course;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final current = CalculatorService.currentCourseGrade(course.components);
    final finalEstimate = CalculatorService.finalCourseEstimate(
      course.components,
    );
    final scale = controller.data.scaleById(course.gradingScaleId);
    final progress = ((current.percent ?? 0) / 100).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CourseDetailScreen(
                semesterId: semesterId,
                courseId: course.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      course.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(scale.labelForPercent(current.percent ?? 0)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.trending_up,
                    label: 'Current ${_formatPercent(current.percent)}',
                  ),
                  _InfoChip(
                    icon: Icons.flag_outlined,
                    label: 'Estimate ${_formatPercent(finalEstimate.percent)}',
                  ),
                  _InfoChip(
                    icon: Icons.credit_score_outlined,
                    label: '${_formatCredits(course.credits)} credits',
                  ),
                ],
              ),
              if (current.hasWeightWarning) ...[
                const SizedBox(height: 10),
                _WarningBanner(
                  message:
                      'Weights total ${_formatNumber(current.totalWeight)}%, not 100%.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoColumnFields extends StatelessWidget {
  const _TwoColumnFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 520
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, hintText: hint),
      onChanged: (_) => onChanged(),
    );
  }
}

class _CourseComponentDraft {
  _CourseComponentDraft({
    String? id,
    String name = '',
    String weight = '',
    String earned = '',
    String possible = '',
  }) : id = id ?? newEntityId('component'),
       nameController = TextEditingController(text: name),
       weightController = TextEditingController(text: weight),
       earnedController = TextEditingController(text: earned),
       possibleController = TextEditingController(text: possible);

  factory _CourseComponentDraft.fromComponent(GradeComponent component) {
    return _CourseComponentDraft(
      id: component.id,
      name: component.name,
      weight: _formatNumber(component.weightPercent),
      earned: component.scoreEarned == null
          ? ''
          : _formatNumber(component.scoreEarned!),
      possible: component.scorePossible == null
          ? ''
          : _formatNumber(component.scorePossible!),
    );
  }

  final String id;
  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController earnedController;
  final TextEditingController possibleController;

  double get weight => _parseDouble(weightController.text) ?? 0;

  GradeComponent toComponent() {
    return GradeComponent(
      id: id,
      name: nameController.text.trim(),
      weightPercent: _parseDouble(weightController.text)!,
      scoreEarned: _parseDouble(earnedController.text),
      scorePossible: _parseDouble(possibleController.text),
    );
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InlineSyllabusDraftCard extends StatelessWidget {
  const _InlineSyllabusDraftCard({
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _CourseComponentDraft draft;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Component ${index + 1}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove component',
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: draft.nameController,
            decoration: const InputDecoration(
              labelText: 'Component name',
              hintText: 'Midterm, Homework, Final',
            ),
            validator: _requiredValidator,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: draft.weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight %'),
            validator: _weightValidator,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: draft.earnedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Score earned',
              hintText: 'Optional',
            ),
            validator: (value) => _scoreValidator(
              value,
              draft.possibleController.text,
              earnedField: true,
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: draft.possibleController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Score possible',
              hintText: 'Optional',
            ),
            validator: (value) => _scoreValidator(
              draft.earnedController.text,
              value,
              earnedField: false,
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _EmptySyllabusInlineActions extends StatelessWidget {
  const _EmptySyllabusInlineActions({
    required this.onAddBlank,
    required this.onUseExample,
  });

  final VoidCallback onAddBlank;
  final VoidCallback onUseExample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No syllabus items yet',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You can save the class now, or add Midterm, Homework, Final, and other weights here.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add syllabus item'),
                onPressed: onAddBlank,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome_motion_outlined),
                label: const Text('Use common setup'),
                onPressed: onUseExample,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightPreview extends StatelessWidget {
  const _WeightPreview({required this.totalWeight});

  final double totalWeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isComplete = (totalWeight - 100).abs() <= 0.01;
    final isOver = totalWeight > 100;
    final color = isComplete
        ? Colors.green
        : isOver
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final label = isComplete
        ? 'Weights total 100%'
        : isOver
        ? '${_formatNumber(totalWeight)}% total, over 100%'
        : '${_formatNumber(totalWeight)}% total, ${_formatNumber(100 - totalWeight)}% left';

    return Row(
      children: [
        Icon(Icons.pie_chart_outline, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

List<_CourseComponentDraft> _commonSyllabusDrafts() {
  return [
    _CourseComponentDraft(name: 'Midterm', weight: '30'),
    _CourseComponentDraft(name: 'Assignments', weight: '30'),
    _CourseComponentDraft(name: 'Final', weight: '40'),
  ];
}

Future<void> showSemesterDialog(
  BuildContext context, {
  Semester? semester,
}) async {
  final controller = AppScope.of(context);
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: semester?.name ?? '');
  var isActive = semester?.isActive ?? controller.semesters.isEmpty;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              semester == null ? 'Create a Semester' : 'Edit Semester',
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogSection(
                      title: 'Semester details',
                      subtitle:
                          'A semester is the term that holds your classes, GPA, and assignments.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Semester name',
                              hintText: 'Fall 2026',
                              helperText: 'Examples: Fall 2026, Spring 2027',
                            ),
                            textInputAction: TextInputAction.done,
                            validator: _requiredValidator,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Make this my active semester'),
                                    SizedBox(height: 2),
                                    Text(
                                      'The dashboard will show this semester first.',
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isActive,
                                onChanged: (value) {
                                  setDialogState(() => isActive = value);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: _saveSemesterKey,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  await controller.upsertSemester(
                    Semester(
                      id: semester?.id ?? newEntityId('semester'),
                      name: nameController.text.trim(),
                      courses: semester?.courses ?? const [],
                      isActive: isActive,
                    ),
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Save Semester'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showCourseDialog(
  BuildContext context, {
  required String semesterId,
  Course? course,
}) async {
  final controller = AppScope.of(context);
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: course?.name ?? '');
  final creditsController = TextEditingController(
    text: course == null ? '' : _formatCredits(course.credits),
  );
  var scaleId = course?.gradingScaleId ?? controller.gradingScales.first.id;
  var componentDrafts =
      course?.components.map(_CourseComponentDraft.fromComponent).toList() ??
      <_CourseComponentDraft>[];

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final totalWeight = componentDrafts.fold<double>(
            0,
            (sum, draft) => sum + draft.weight,
          );
          return AlertDialog(
            title: Text(course == null ? 'Create a Class' : 'Edit Class'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogSection(
                      title: '1. Class basics',
                      subtitle:
                          'Name the class, add credits, and choose the grading system used by your school.',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Class / course name',
                              hintText: 'Calculus I',
                            ),
                            validator: _requiredValidator,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: creditsController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Credits',
                              hintText: '3',
                            ),
                            validator: (value) => _positiveNumberValidator(
                              value,
                              field: 'Credits',
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: scaleId,
                            decoration: const InputDecoration(
                              labelText: 'Grading scale',
                            ),
                            items: controller.gradingScales
                                .map(
                                  (scale) => DropdownMenuItem(
                                    value: scale.id,
                                    child: Text(scale.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => scaleId = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DialogSection(
                      title: '2. Syllabus & grades',
                      subtitle:
                          'Add weights now so current grades and GPA are useful right away. Scores are optional.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (componentDrafts.isEmpty)
                            _EmptySyllabusInlineActions(
                              onAddBlank: () {
                                setDialogState(() {
                                  componentDrafts = [
                                    ...componentDrafts,
                                    _CourseComponentDraft(),
                                  ];
                                });
                              },
                              onUseExample: () {
                                setDialogState(() {
                                  componentDrafts = _commonSyllabusDrafts();
                                });
                              },
                            )
                          else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _WeightPreview(
                                    totalWeight: totalWeight,
                                  ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add item'),
                                  onPressed: () {
                                    setDialogState(() {
                                      componentDrafts = [
                                        ...componentDrafts,
                                        _CourseComponentDraft(),
                                      ];
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            for (
                              var index = 0;
                              index < componentDrafts.length;
                              index++
                            )
                              _InlineSyllabusDraftCard(
                                index: index,
                                draft: componentDrafts[index],
                                onChanged: () => setDialogState(() {}),
                                onRemove: () {
                                  setDialogState(() {
                                    componentDrafts = [...componentDrafts]
                                      ..removeAt(index);
                                  });
                                },
                              ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: const Text('Replace with common syllabus'),
                              onPressed: () {
                                setDialogState(() {
                                  componentDrafts = _commonSyllabusDrafts();
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: _saveCourseKey,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  await controller.upsertCourse(
                    semesterId,
                    Course(
                      id: course?.id ?? newEntityId('course'),
                      name: nameController.text.trim(),
                      credits: _parseDouble(creditsController.text)!,
                      gradingScaleId: scaleId,
                      components: componentDrafts
                          .map((draft) => draft.toComponent())
                          .toList(),
                    ),
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Save Class & Syllabus'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showComponentDialog(
  BuildContext context, {
  required String semesterId,
  required String courseId,
  GradeComponent? component,
}) async {
  final controller = AppScope.of(context);
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: component?.name ?? '');
  final weightController = TextEditingController(
    text: component == null ? '' : _formatNumber(component.weightPercent),
  );
  final earnedController = TextEditingController(
    text: component?.scoreEarned == null
        ? ''
        : _formatNumber(component!.scoreEarned!),
  );
  final possibleController = TextEditingController(
    text: component?.scorePossible == null
        ? ''
        : _formatNumber(component!.scorePossible!),
  );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          component == null ? 'Add grade component' : 'Edit grade component',
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Component name',
                    hintText: 'Midterm, Final, Homework',
                  ),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Weight %'),
                  validator: _weightValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: earnedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Score earned'),
                  validator: (value) => _scoreValidator(
                    value,
                    possibleController.text,
                    earnedField: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: possibleController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Score possible',
                  ),
                  validator: (value) => _scoreValidator(
                    earnedController.text,
                    value,
                    earnedField: false,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              final earned = _parseDouble(earnedController.text);
              final possible = _parseDouble(possibleController.text);
              await controller.upsertComponent(
                semesterId,
                courseId,
                GradeComponent(
                  id: component?.id ?? newEntityId('component'),
                  name: nameController.text.trim(),
                  weightPercent: _parseDouble(weightController.text)!,
                  scoreEarned: earned,
                  scorePossible: possible,
                ),
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Save Component'),
          ),
        ],
      );
    },
  );
}

Future<void> showAssignmentDialog(
  BuildContext context, {
  AssignmentItem? assignment,
  String? courseId,
}) async {
  final controller = AppScope.of(context);
  final courses = controller.semesters
      .expand((semester) => semester.courses)
      .toList();
  if (courses.isEmpty) {
    _showMessage(context, 'Add a course before adding assignments.');
    return;
  }

  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController(text: assignment?.title ?? '');
  var selectedCourseId = assignment?.courseId ?? courseId ?? courses.first.id;
  var dueDate = assignment?.dueDate ?? DateTime.now();
  var completed = assignment?.completed ?? false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              assignment == null ? 'Add assignment' : 'Edit assignment',
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCourseId,
                      decoration: const InputDecoration(labelText: 'Course'),
                      items: courses
                          .map(
                            (course) => DropdownMenuItem(
                              value: course.id,
                              child: Text(course.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedCourseId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Due date'),
                      subtitle: Text(DateFormat('MMM d, y').format(dueDate)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: dueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => dueDate = picked);
                        }
                      },
                    ),
                    CheckboxListTile(
                      value: completed,
                      onChanged: (value) {
                        setDialogState(() => completed = value ?? false);
                      },
                      title: const Text('Completed'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: _saveAssignmentKey,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  await controller.upsertAssignment(
                    AssignmentItem(
                      id: assignment?.id ?? newEntityId('assignment'),
                      title: titleController.text.trim(),
                      dueDate: dueDate,
                      courseId: selectedCourseId,
                      completed: completed,
                    ),
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Save Assignment'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

Future<void> _loadExampleData(BuildContext context) async {
  final controller = AppScope.of(context);
  final semesterId = newEntityId('semester');
  final statisticsId = newEntityId('course');
  final writingId = newEntityId('course');
  final dueDate = DateTime.now().add(const Duration(days: 6));

  await controller.upsertSemester(
    Semester(
      id: semesterId,
      name: 'Example Fall 2026',
      isActive: true,
      courses: [
        Course(
          id: statisticsId,
          name: 'Statistics 101',
          credits: 3,
          gradingScaleId: 'us_4',
          components: [
            GradeComponent(
              id: newEntityId('component'),
              name: 'Midterm',
              weightPercent: 30,
              scoreEarned: 80,
              scorePossible: 100,
            ),
            GradeComponent(
              id: newEntityId('component'),
              name: 'Assignments',
              weightPercent: 30,
              scoreEarned: 90,
              scorePossible: 100,
            ),
            GradeComponent(
              id: newEntityId('component'),
              name: 'Final',
              weightPercent: 40,
            ),
          ],
        ),
        Course(
          id: writingId,
          name: 'Academic Writing',
          credits: 3,
          gradingScaleId: 'percentage',
          components: [
            GradeComponent(
              id: newEntityId('component'),
              name: 'Essay Drafts',
              weightPercent: 35,
              scoreEarned: 31,
              scorePossible: 35,
            ),
            GradeComponent(
              id: newEntityId('component'),
              name: 'Participation',
              weightPercent: 15,
              scoreEarned: 14,
              scorePossible: 15,
            ),
            GradeComponent(
              id: newEntityId('component'),
              name: 'Final Portfolio',
              weightPercent: 50,
            ),
          ],
        ),
      ],
    ),
  );

  await controller.upsertAssignment(
    AssignmentItem(
      id: newEntityId('assignment'),
      title: 'Statistics problem set',
      dueDate: dueDate,
      courseId: statisticsId,
    ),
  );

  if (context.mounted) {
    _showMessage(context, 'Example semester added.');
  }
}

Future<void> _applyExampleComponents(
  BuildContext context, {
  required String semesterId,
  required String courseId,
}) async {
  final controller = AppScope.of(context);
  await controller.upsertComponent(
    semesterId,
    courseId,
    GradeComponent(
      id: newEntityId('component'),
      name: 'Midterm',
      weightPercent: 30,
    ),
  );
  await controller.upsertComponent(
    semesterId,
    courseId,
    GradeComponent(
      id: newEntityId('component'),
      name: 'Assignments',
      weightPercent: 30,
    ),
  );
  await controller.upsertComponent(
    semesterId,
    courseId,
    GradeComponent(
      id: newEntityId('component'),
      name: 'Final',
      weightPercent: 40,
    ),
  );

  if (context.mounted) {
    _showMessage(context, 'Example syllabus added.');
  }
}

List<AssignmentItem> _upcomingAssignments(AppController controller) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return controller.assignments
      .where(
        (assignment) =>
            !assignment.completed && !assignment.dueDate.isBefore(today),
      )
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
}

String? _requiredValidator(String? value) {
  return InputValidationService.requiredText(value);
}

String? _positiveNumberValidator(String? value, {required String field}) {
  return InputValidationService.positiveNumber(value, field: field);
}

String? _weightValidator(String? value) {
  return InputValidationService.componentWeight(value);
}

String? _scoreValidator(
  String? earnedText,
  String? possibleText, {
  required bool earnedField,
}) {
  return InputValidationService.componentScore(
    earnedText,
    possibleText,
    earnedField: earnedField,
  );
}

double? _parseDouble(String? value) {
  return InputValidationService.parseDouble(value);
}

String _formatPercent(double? value) {
  if (value == null || value.isNaN) {
    return '--';
  }
  return '${value.toStringAsFixed(1)}%';
}

String _formatGpa(double? value) {
  if (value == null || value.isNaN) {
    return '--';
  }
  return value.toStringAsFixed(2);
}

String _formatCredits(double value) {
  return _formatNumber(value);
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
