import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class CustomAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBackButton;
  final double? expandedHeight;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final bool showElevation;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBackButton = false,
    this.expandedHeight,
    this.leading,
    this.centerTitle = false,
    this.backgroundColor,
    this.showElevation = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveExpandedHeight =
        expandedHeight ?? (subtitle != null ? 152.0 : 125.0);

    return SliverAppBar(
      expandedHeight: effectiveExpandedHeight,
      floating: false,
      pinned: true,
      backgroundColor: backgroundColor ?? AppTheme.primaryGreen,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: showBackButton,
      leading: leading,
      actions: actions != null
          ? [
              ...actions!.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: action,
                ),
              ),
              const SizedBox(width: 8),
            ]
          : null,
      elevation: showElevation ? 4 : 0,
      shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: centerTitle,
        titlePadding: EdgeInsets.only(
          left: showBackButton || leading != null ? 56 : 20,
          right: actions != null ? 16 : 20,
          bottom: 10,
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: centerTitle
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black26,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                backgroundColor ?? AppTheme.primaryGreen,
                (backgroundColor ?? AppTheme.primaryGreen).withValues(alpha: 0.8),
                AppTheme.lightGreen,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                // Decorative background pattern
                Positioned(
                  right: screenWidth * 0.1,
                  top: -20,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: screenWidth * 0.3,
                  top: -40,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  left: screenWidth * 0.1,
                  bottom: -30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                // Geometric accent
                Positioned(
                  right: 20,
                  top: 30,
                  child: Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  right: 30,
                  top: 35,
                  child: Container(
                    width: 4,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
