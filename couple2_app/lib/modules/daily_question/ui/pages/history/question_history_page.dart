import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/session_provider.dart';
import '../../../domain/domain.dart';
import 'question_history_viewmodel.dart';

class QuestionHistoryPage extends ConsumerStatefulWidget {
  const QuestionHistoryPage({super.key});

  @override
  ConsumerState<QuestionHistoryPage> createState() =>
      _QuestionHistoryPageState();
}

class _QuestionHistoryPageState extends ConsumerState<QuestionHistoryPage> {
  final _scroll = ScrollController();
  final _draft = TextEditingController();
  String? _editingId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent - 240) {
        ref.read(questionHistoryViewModelProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _draft.dispose();
    super.dispose();
  }

  void _openComposer(CoupleQuestion question) {
    setState(() {
      _editingId = question.id;
      _draft.text = question.myAnswer?.text ?? '';
    });
  }

  Future<void> _submit(CoupleQuestion question) async {
    final saved = await ref
        .read(questionHistoryViewModelProvider.notifier)
        .answer(question.id, _draft.text);
    if (!saved || !mounted) return;
    setState(() => _editingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questionHistoryViewModelProvider);
    final viewModel = ref.read(questionHistoryViewModelProvider.notifier);
    final partnerRaw = ref
        .watch(sessionProvider)
        .asData
        ?.value
        ?.partnerName
        ?.trim();
    final partner = (partnerRaw == null || partnerRaw.isEmpty)
        ? 'seu par'
        : partnerRaw;

    return Scaffold(
      appBar: AppBar(title: const AppText('Histórico')),
      body: RefreshIndicator(
        onRefresh: viewModel.refresh,
        child: state.isLoading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.items.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == state.items.length) {
                    return _HistoryFooter(state: state);
                  }
                  final question = state.items[index];
                  return _HistoryTile(
                    question: question,
                    partnerName: partner,
                    editing: _editingId == question.id,
                    saving: state.isSaving && _editingId == question.id,
                    draft: _draft,
                    onAnswer: () => _openComposer(question),
                    onSubmit: () => _submit(question),
                  );
                },
              ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.question,
    required this.partnerName,
    required this.editing,
    required this.saving,
    required this.draft,
    required this.onAnswer,
    required this.onSubmit,
  });

  final CoupleQuestion question;
  final String partnerName;
  final bool editing;
  final bool saving;
  final TextEditingController draft;
  final VoidCallback onAnswer;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final showAnswer = showHistoryAnswerCta(
      answerable: question.answerable,
      answeredByMe: question.answeredByMe,
    );
    final showEdit = showHistoryEditCta(
      answerable: question.answerable,
      answeredByMe: question.answeredByMe,
      unlocked: question.unlocked,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            formatCalendarDate(question.date),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          AppText(questionCategoryLabel(question.question.category)),
          const SizedBox(height: 8),
          AppText(question.question.text),
          const SizedBox(height: 8),
          if (question.unlocked) ...[
            AppText('Você: ${question.myAnswer?.text ?? ''}'),
            const SizedBox(height: 4),
            AppText('$partnerName: ${question.partnerAnswer?.text ?? ''}'),
          ] else if (question.answeredByMe)
            AppText('Você respondeu, aguardando $partnerName'),
          if (showAnswer || showEdit) ...[
            const SizedBox(height: 8),
            if (!editing)
              TextButton(
                onPressed: onAnswer,
                child: Text(showAnswer ? 'Responder' : 'Editar'),
              )
            else ...[
              TextField(
                controller: draft,
                maxLength: 1000,
                minLines: 2,
                maxLines: 6,
                enabled: !saving,
                decoration: const InputDecoration(
                  hintText: 'Sua resposta',
                  border: OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: saving ? null : onSubmit,
                  child: Text(showAnswer ? 'Enviar' : 'Editar'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _HistoryFooter extends StatelessWidget {
  const _HistoryFooter({required this.state});

  final QuestionHistoryState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppText(state.errorMessage!),
          ),
        if (state.items.isEmpty && state.errorMessage == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: AppText('Nenhuma pergunta ainda.'),
          ),
        if (state.isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          const SizedBox(height: 24),
      ],
    );
  }
}
