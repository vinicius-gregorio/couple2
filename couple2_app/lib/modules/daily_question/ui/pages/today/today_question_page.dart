import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/session_provider.dart';
import '../../../domain/domain.dart';
import '../../../routing/routes.dart';
import 'today_question_viewmodel.dart';

class TodayQuestionPage extends ConsumerStatefulWidget {
  const TodayQuestionPage({super.key});

  @override
  ConsumerState<TodayQuestionPage> createState() => _TodayQuestionPageState();
}

class _TodayQuestionPageState extends ConsumerState<TodayQuestionPage> {
  final _controller = TextEditingController();
  String? _filledFor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayQuestionViewModelProvider);
    final viewModel = ref.read(todayQuestionViewModelProvider.notifier);
    final partnerName =
        ref.watch(sessionProvider).asData?.value?.partnerName ?? '';
    final question = state.question;
    if (question != null && !question.unlocked && _filledFor != question.id) {
      final draft = question.myAnswer?.text ?? '';
      final id = question.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _filledFor == id) return;
        _filledFor = id;
        _controller.text = draft;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Pergunta do dia'),
        actions: [
          IconButton(
            tooltip: 'Histórico',
            onPressed: () => context.push(DailyQuestionRoutes.history),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.load,
        child: state.isLoading && question == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AppText(state.errorMessage!),
                    ),
                  if (question == null)
                    const AppText('Não foi possível carregar a pergunta.')
                  else ...[
                    AppText(
                      questionCategoryLabel(question.question.category),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    AppText(
                      question.question.text,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    if (question.unlocked)
                      _UnlockedAnswers(
                        mine: question.myAnswer?.text ?? '',
                        partner: question.partnerAnswer?.text ?? '',
                        partnerName: partnerName.trim().isEmpty
                            ? 'Seu par'
                            : partnerName.trim(),
                      )
                    else ...[
                      TextField(
                        controller: _controller,
                        maxLength: 1000,
                        minLines: 4,
                        maxLines: 8,
                        enabled: !state.isSaving,
                        decoration: const InputDecoration(
                          hintText: 'Sua resposta',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: state.isSaving
                              ? null
                              : () => viewModel.submit(_controller.text),
                          child: Text(
                            question.answeredByMe ? 'Editar' : 'Enviar',
                          ),
                        ),
                      ),
                      if (question.answeredByMe && !question.partnerAnswered)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: AppText(
                            'Resposta enviada. A resposta do seu par aparece quando os dois tiverem respondido.',
                          ),
                        ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _UnlockedAnswers extends StatelessWidget {
  const _UnlockedAnswers({
    required this.mine,
    required this.partner,
    required this.partnerName,
  });

  final String mine;
  final String partner;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _AnswerColumn(title: 'Você', text: mine),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AnswerColumn(title: partnerName, text: partner),
        ),
      ],
    );
  }
}

class _AnswerColumn extends StatelessWidget {
  const _AnswerColumn({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            AppText(text.isEmpty ? 'Sem resposta' : text),
          ],
        ),
      ),
    );
  }
}
