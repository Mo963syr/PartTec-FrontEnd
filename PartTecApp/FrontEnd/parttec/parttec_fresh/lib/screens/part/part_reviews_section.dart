import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/reviews_provider.dart';
import '../../providers/auth_provider.dart';

class PartReviewsSection extends StatelessWidget {
  final String partId;
  const PartReviewsSection({super.key, required this.partId});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final insideScrollView = Scrollable.of(context) != null;

    // استخدم Padding عادي لتقليل إعادة البناء العنيفة
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min, // مهم داخل Scroll/كرت
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentsList(partId: partId, insideScrollView: insideScrollView),
          const SizedBox(height: 8),
          SafeArea(top: false, child: _CommentComposer(partId: partId)),
        ],
      ),
    );
  }
}

class SafeTextController extends TextEditingController {
  void setTextSafely(String text) {
    value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  void clearSafely() => setTextSafely('');
}

class _CommentComposer extends StatefulWidget {
  final String partId;
  const _CommentComposer({required this.partId});

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final _ctrl = SafeTextController();
  final _focus = FocusNode(debugLabel: 'comment_field_focus');
  bool _sending = false;

  // حارس تركيز يمنع فقدانه فور اللمس
  bool _armKeepFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // إذا فقد التركيز مباشرة بعد محاولة أخذه، أعد طلبه مرة واحدة
      if (_armKeepFocus && !_focus.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focus.requestFocus();
        });
        // نفك التسليح بعد المحاولة كي لا ندخل حلقة
        _armKeepFocus = false;
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;

    final content = _ctrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب تعليقاً أولاً')),
      );
      return;
    }

    final uid = context.read<AuthProvider>().userId ?? '';
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول أولاً')),
      );
      return;
    }

    setState(() => _sending = true);
    final ok = await context.read<ReviewsProvider>().addComment(
          partId: widget.partId,
          userId: uid,
          content: content,
        );
    if (!mounted) return;
    setState(() => _sending = false);

    if (ok) {
      _ctrl.clearSafely();
      _armKeepFocus = false;
      _focus.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ تعليقك ✅')),
      );
      context.read<ReviewsProvider>().fetchPartComments(widget.partId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل حفظ التعليق ❌')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أضف تعليقك:'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                // استخدم لون الحدود من الثيم بدلاً من الرمادي الصريح
                border: Border.all(color: AppColors.chipBorder),
                borderRadius: BorderRadius.circular(8),
                // ولون الكارد من الثيم بدلاً من الأبيض الصريح
                color: AppColors.card,
              ),
              child: CupertinoTextField(
                key: const ValueKey('comment_field_key'), // يحافظ على الهوية
                focusNode: _focus,
                controller: _ctrl,
                maxLines: 3,
                minLines: 1,
                padding: const EdgeInsets.all(12),
                placeholder: 'اكتب تعليقًا ...',
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                clearButtonMode: OverlayVisibilityMode.never,
                onTap: () {
                  // نسلّح الحارس ثم نطلب التركيز — لو فقد فورًا سيعيد طلبه
                  _armKeepFocus = true;
                  if (!_focus.hasFocus) _focus.requestFocus();
                },
                // بعض القنوات تدعم onTapOutside على CupertinoTextField
                // نتجاهلها كي لا تُغلق الكيبورد تلقائياً
                onTapOutside: (_) {}, // يتطلب Flutter حديث؛ إن لم يدعم تجاهله
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send),
              label: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsList extends StatefulWidget {
  final String partId;
  final bool insideScrollView;
  const _CommentsList({
    required this.partId,
    required this.insideScrollView,
  });

  @override
  State<_CommentsList> createState() => _CommentsListState();
}

class _CommentsListState extends State<_CommentsList> {
  bool _fetched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_fetched) {
        context.read<ReviewsProvider>().fetchPartComments(widget.partId);
        _fetched = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewsProvider>(
      builder: (_, p, __) {
        if (p.isLoading && p.comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (p.comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('لا توجد تعليقات بعد.'),
          );
        }

        if (widget.insideScrollView) {

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(p.comments.length, (i) {
                final c = p.comments[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person),
                      title: Text(
                        c.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.content),
                          const SizedBox(height: 4),
                          Text(
                            '${c.createdAt}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (i != p.comments.length - 1) const Divider(height: 8),
                  ],
                );
              }),
            ),
          );
        }


        return SizedBox(
          height: 260,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            itemCount: p.comments.length,
            separatorBuilder: (_, __) => const Divider(height: 8),
            itemBuilder: (_, i) {
              final c = p.comments[i];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(
                  c.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.content),
                    const SizedBox(height: 4),
                    Text(
                      '${c.createdAt}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
