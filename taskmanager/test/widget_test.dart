
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/main.dart';

void main() {
  testWidgets(
    'Task Manager hien thi man hinh dang nhap',
    (WidgetTester tester) async {
      await tester.pumpWidget(const TaskManagerApp());

      // Kiểm tra tiêu đề màn hình đăng nhập.
      expect(find.text('Chào mừng trở lại'), findsOneWidget);

      // Kiểm tra thông tin giới thiệu.
      expect(
        find.text('Đăng nhập để quản lý công việc và nhóm của bạn'),
        findsOneWidget,
      );

      // Kiểm tra có hai trường nhập email và mật khẩu.
      expect(find.byType(TextFormField), findsNWidgets(2));

      // Kiểm tra có nút đăng nhập.
      expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);

      // Kiểm tra biểu tượng Task Manager.
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    },
  );
}
