import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/schedule/tien_mon_schedule_views.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/tien_mon_premium_contract.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/material.dart';

DateTime weekMonday(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);

const _premiumGoldShadows = tienMonTextShadows;

class WeekTimetable extends StatelessWidget {
  const new({
    required this.data,
    required this.week,
    required this.onWeekChanged,
    required this.onPickWeek,
    super.key,
  });

  final ImportedScheduleData data;
  final DateTime week;
  final ValueChanged<DateTime> onWeekChanged;
  final VoidCallback onPickWeek;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final premium = palette.id == AppThemeId.tienMonPremium;
    final monday = weekMonday(week);
    final sunday = monday.add(const Duration(days: 6));
    final scene = TienMonPremiumContract.appSceneFor(DateTime.now());
    final header = Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Tuần trước',
          onPressed: () =>
              onWeekChanged(monday.subtract(const Duration(days: 7))),
          icon: Icon(
            Icons.chevron_left_rounded,
            color: premium ? const Color(0xFFFFD66B) : null,
            shadows: premium ? _premiumGoldShadows : null,
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: onPickWeek,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                '${_shortDate(monday)} – ${_shortDate(sunday)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                  shadows: premium ? _premiumGoldShadows : null,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Tuần sau',
          onPressed: () => onWeekChanged(monday.add(const Duration(days: 7))),
          icon: Icon(
            Icons.chevron_right_rounded,
            color: premium ? const Color(0xFFFFD66B) : null,
            shadows: premium ? _premiumGoldShadows : null,
          ),
        ),
      ],
    );
    return Column(
      children: <Widget>[
        if (premium)
          TienMonEdgeSurface(compact: true, scene: scene, child: header)
        else
          header,
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            layoutBuilder: (current, previous) =>
                current ?? const SizedBox.shrink(),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: ListView.separated(
              key: ValueKey<DateTime>(monday),
              padding: const EdgeInsets.only(bottom: 86),
              itemCount: 7,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, dayIndex) {
                final date = monday.add(Duration(days: dayIndex));
                final records = data.classes
                    .where(
                      (row) =>
                          row.startAt.year == date.year &&
                          row.startAt.month == date.month &&
                          row.startAt.day == date.day,
                    )
                    .toList();
                final rowContent = Row(
                  children: <Widget>[
                    SizedBox(
                      width: 79,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 9),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              dayIndex == 6
                                  ? 'Chủ nhật'
                                  : 'Thứ ${dayIndex + 2}',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                shadows: premium ? _premiumGoldShadows : null,
                              ),
                            ),
                            Text(
                              _shortDate(date),
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 12,
                                shadows: premium ? _premiumGoldShadows : null,
                              ),
                            ),
                            if (records.isNotEmpty)
                              Text(
                                '${records.length} buổi',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 10,
                                  shadows: premium ? _premiumGoldShadows : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: records.isEmpty
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Không có lịch học',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 12,
                                  shadows: premium ? _premiumGoldShadows : null,
                                ),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 3,
                              ),
                              itemCount: records.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                final row = records[index];
                                final content = Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    5,
                                    6,
                                    5,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        row.subjectName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          shadows: premium
                                              ? _premiumGoldShadows
                                              : null,
                                        ),
                                      ),
                                      Text(
                                        '${_time(row.startAt)} – ${_time(row.endAt)}',
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 10,
                                          shadows: premium
                                              ? _premiumGoldShadows
                                              : null,
                                        ),
                                      ),
                                      Text(
                                        row.room,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontSize: 10,
                                          shadows: premium
                                              ? _premiumGoldShadows
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (premium) {
                                  return SizedBox(
                                    width: 135,
                                    child: TienMonEdgeSurface(
                                      compact: true,
                                      scene: scene,
                                      child: content,
                                    ),
                                  );
                                }
                                return Container(
                                  width: 135,
                                  decoration: BoxDecoration(
                                    color: palette.surface,
                                    border: Border(
                                      left: BorderSide(
                                        color: palette.primary,
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                  child: content,
                                );
                              },
                            ),
                    ),
                  ],
                );
                if (premium) {
                  return SizedBox(
                    height: 86,
                    child: TienMonEdgeSurface(
                      compact: true,
                      scene: scene,
                      child: rowContent,
                    ),
                  );
                }
                return Container(
                  height: 86,
                  decoration: BoxDecoration(
                    color: palette.cardAlt,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: palette.border),
                  ),
                  child: rowContent,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  static String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
