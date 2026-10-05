import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';

/**
 * pt-BR question bank for Pergunta do dia.
 * Source for the Prisma data migration. Do not put these rows in supabase/seed.sql.
 * Deactivate a question with active=false in a later migration; never DELETE.
 *
 * Non-DEEP questions are >= 120 so a couple can go 120 days without a repeat
 * even when DEEP is capped at one per week.
 */

function numbered(prefix, category, texts) {
  return texts.map((text, index) => ({
    slug: `${prefix}-${String(index + 1).padStart(3, '0')}`,
    category,
    text,
  }));
}

export const QUESTION_BANK = [
  ...numbered('fun', 'FUN', [
    'Se o nosso casal fosse um filme, qual seria o título?',
    'Qual música descreve a gente hoje?',
    'Se a gente tivesse um restaurante só nosso, qual seria o prato da casa?',
    'Se a gente trocasse de corpo por um dia, o que você faria primeiro?',
    'Qual emoji combina mais com o nosso relacionamento?',
    'Qual seria o nome do nosso barco, se tivéssemos um?',
    'Que superpoder você me emprestaria por uma tarde?',
    'Qual série a gente deveria começar juntos esta semana?',
    'Se a gente formasse uma banda, qual seria o nome?',
    'Qual comida você nunca recusa quando eu ofereço?',
    'Qual é a nossa piada interna favorita?',
    'Se o dia de hoje virasse desenho animado, qual seria a cena?',
    'Qual fantasia de carnaval a gente usaria lado a lado?',
    'Que talento inútil você gostaria que eu tivesse?',
    'Qual seria o nosso grito de guerra antes de uma viagem?',
    'Se a gente abrisse um café, o que teria no cardápio?',
    'Qual animal representa melhor o nosso casal?',
    'Que apelido secreto você me daria hoje?',
    'Qual seria a trilha sonora do nosso café da manhã?',
    'Se a gente ganhasse um fim de semana sem celular, o que faríamos?',
    'Qual sobremesa conta a história da gente?',
    'Que personagem de filme eu seria, segundo você?',
    'Qual seria o nosso esporte olímpico imaginário?',
    'Se a nossa casa tivesse um mascote oficial, qual seria?',
    'Qual meme descreve a gente nesta semana?',
    'Que aula maluca a gente faria juntos só pela diversão?',
    'Qual seria o nome da nossa playlist de domingo?',
    'Se a gente fosse um sabor de sorvete, qual seria?',
    'Que brincadeira de infância a gente deveria repetir?',
    'Qual seria o nosso recorde mundial mais bobo?',
    'Se eu te desse um troféu hoje, o que estaria escrito nele?',
    'Qual filme a gente precisa rever rindo junto?',
  ]),
  ...numbered('memories', 'MEMORIES', [
    'Qual foi o momento em que você pensou que queria ficar comigo?',
    'Qual detalhe do nosso primeiro encontro você ainda lembra?',
    'Qual passeio você repetiria sem mudar nada?',
    'Qual recado meu você guardou?',
    'Qual foto nossa você mostraria para alguém que acabou de te conhecer?',
    'Qual foi a primeira coisa que você admirou em mim?',
    'Qual dia comum nosso virou uma lembrança boa?',
    'Qual comida está ligada a um dia nosso?',
    'Qual música te leva de volta para a gente?',
    'Qual foi o presente mais simples que você ainda lembra?',
    'Qual conversa nossa você gostaria de ouvir de novo?',
    'Qual lugar da cidade é nosso?',
    'Qual foi a primeira risada que você lembra da gente?',
    'Qual plano que deu errado acabou ficando bom?',
    'Qual história nossa você contaria num jantar?',
    'Qual cheiro te lembra a gente?',
    'Qual dia difícil a gente atravessou junto e você ainda guarda com carinho?',
    'Qual mensagem antiga você releria hoje?',
    'Qual foi o primeiro apelido entre a gente?',
    'Qual passeio curto você guarda com carinho?',
    'Qual tradição pequena a gente já criou sem perceber?',
    'Qual foi a última vez que a gente se surpreendeu juntos?',
    'Qual roupa minha você associa a uma lembrança?',
    'Qual foi um sim seu que mudou o nosso caminho?',
    'Qual dia de chuva nosso você lembra?',
    'Qual frase minha ficou com você?',
    'Qual foi o nosso primeiro a gente em vez de eu?',
    'Qual lugar você quer revisitar só pela memória?',
    'Qual gentileza pequena eu fiz e você não esqueceu?',
    'Qual festa, filme ou show a gente viveu junto?',
    'Qual foi o momento em que você se sentiu em casa comigo?',
    'Qual lembrança nossa você contaria daqui a vinte anos?',
  ]),
  ...numbered('future', 'FUTURE', [
    'Que viagem a gente ainda precisa fazer juntos?',
    'Como você imagina um domingo nosso daqui a cinco anos?',
    'Qual hábito a gente poderia começar neste mês?',
    'Que canto da casa você sonha para a gente?',
    'Qual cidade você gostaria de descobrir comigo?',
    'Que tradição nova a gente inventa a partir de agora?',
    'O que você quer aprender junto comigo?',
    'Qual projeto pequeno a gente pode terminar neste ano?',
    'Como você quer comemorar o nosso próximo aniversário de casal?',
    'Que receita a gente deveria dominar juntos?',
    'Qual lugar perto da gente ainda está inexplorado?',
    'O que você quer que a gente proteja na nossa rotina?',
    'Qual sonho seu eu ainda conheço pouco?',
    'Que fim de semana temático a gente poderia planejar?',
    'Como você imagina as nossas manhãs daqui a um tempo?',
    'Qual habilidade você quer que a gente pratique lado a lado?',
    'Que foto a gente ainda não tirou?',
    'Qual meta de um ano cabe na nossa vida real?',
    'Onde você gostaria de acordar nas próximas férias?',
    'Que livro ou curso a gente pode fazer em dupla?',
    'Qual combinado simples deixaria a semana mais leve?',
    'Que celebração pequena a gente pode criar todo mês?',
    'Como você quer que a gente se apoie num ano ocupado?',
    'Qual lugar da casa a gente poderia cuidar juntos?',
    'Que experiência ao ar livre você quer viver comigo?',
    'Qual plano adiado a gente tira do papel?',
    'O que você quer que continue igual entre a gente?',
    'Qual idioma, prato ou dança a gente experimenta juntos?',
    'Como seria um dia perfeito e possível no próximo mês?',
    'Que carta a gente poderia escrever para abrir daqui a um ano?',
  ]),
  ...numbered('daily', 'DAILY_LIFE', [
    'O que deixou o seu dia mais leve hoje?',
    'Qual foi o melhor pedaço do seu dia até agora?',
    'O que você precisa de mim nesta semana, na prática?',
    'Qual tarefa chata a gente pode dividir?',
    'O que você quer jantar quando não quiser decidir?',
    'Qual horário do dia é mais seu, e como eu respeito isso?',
    'O que te recarrega em vinte minutos?',
    'Qual pequena gentileza eu posso fazer amanhã?',
    'O que está ocupando a sua cabeça hoje?',
    'Qual parte da rotina a gente poderia simplificar?',
    'Como você prefere receber cuidado num dia corrido?',
    'O que você quer comemorar, mesmo que seja pequeno?',
    'Qual combinado de celular deixaria a gente mais presente?',
    'O que você está evitando e eu posso ajudar a começar?',
    'Qual é o seu não desta semana, para proteger o descanso?',
    'O que te fez sorrir hoje fora de casa?',
    'Qual refeição a gente transforma em encontro esta semana?',
    'O que você quer que eu pergunte mais vezes?',
    'Qual canto da casa está pedindo atenção?',
    'Como foi o seu sono, de verdade?',
    'O que você quer fazer hoje à noite, do jeito mais simples?',
    'Qual assunto prático a gente resolve em dez minutos?',
    'O que te cansou hoje e já pode ficar do lado de fora?',
    'Qual café, praça ou padaria merece uma visita nossa?',
    'O que você quer ouvir de mim num dia comum?',
    'Qual responsabilidade a gente pode revezar melhor?',
    'O que você está com vontade de cozinhar ou pedir?',
    'Qual pausa curta caberia no nosso dia de amanhã?',
    'O que você quer largar na porta antes de chegar em casa?',
    'Qual detalhe do meu dia você gostaria de saber hoje?',
  ]),
  ...numbered('deep', 'DEEP', [
    'O que em mim te faz sentir segurança?',
    'Qual valor nosso você não abriria mão?',
    'Quando você se sente mais amado por mim?',
    'O que você aprendeu sobre si desde que a gente está junto?',
    'O que casa significa para você quando pensa na gente?',
    'Qual parte da sua história você gosta de compartilhar comigo?',
    'Como você pede ajuda quando precisa, e como eu posso perceber?',
    'O que você admira em mim e ainda não disse em voz alta?',
    'Qual combinado deixa a gente mais leve depois de um desentendimento?',
    'O que você quer que eu entenda sobre o seu jeito de amar?',
    'Qual sonho seu merece mais espaço na nossa conversa?',
    'Quando você se sente mais você, ao meu lado?',
    'O que gratidão parece, concretamente, entre a gente?',
    'Qual limite seu eu deveria conhecer melhor?',
    'O que você espera que a gente ainda descubra um sobre o outro?',
    'Qual cuidado pequeno faz você se sentir escolhido?',
  ]),
];

export function stableQuestionId(slug) {
  const hex = createHash('sha256')
    .update(`couple2:question:${slug}`)
    .digest('hex');
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32),
  ].join('-');
}

function sqlString(value) {
  return `'${value.replaceAll("'", "''")}'`;
}

export function renderQuestionSeedSql(bank = QUESTION_BANK) {
  const values = bank.map((question) => {
    const id = stableQuestionId(question.slug);
    return `  (${sqlString(id)}, ${sqlString(question.slug)}, ${sqlString(question.text)}, 'pt-BR', '${question.category}', true, CURRENT_TIMESTAMP)`;
  });
  return `-- Idempotent pt-BR bank. Running this INSERT twice does not create duplicates.
INSERT INTO "questions" ("id", "slug", "text", "locale", "category", "active", "createdAt")
VALUES
${values.join(',\n')}
ON CONFLICT ("slug") DO NOTHING;
`;
}

export function assertQuestionBank(bank = QUESTION_BANK) {
  const slugs = new Set();
  const allowed = new Set([
    'FUN',
    'DEEP',
    'MEMORIES',
    'FUTURE',
    'DAILY_LIFE',
  ]);
  let nonDeep = 0;
  for (const question of bank) {
    if (slugs.has(question.slug)) {
      throw new Error(`Duplicate slug ${question.slug}`);
    }
    slugs.add(question.slug);
    if (!allowed.has(question.category)) {
      throw new Error(`Bad category ${question.category}`);
    }
    if (!question.text.trim()) {
      throw new Error(`Empty text for ${question.slug}`);
    }
    if (question.category !== 'DEEP') nonDeep += 1;
  }
  if (bank.length < 120) {
    throw new Error(`Question bank has ${bank.length} rows, need at least 120`);
  }
  if (nonDeep < 120) {
    throw new Error(
      `Need at least 120 non-DEEP questions so the weekly cap cannot force a repeat inside 120 days (have ${nonDeep})`,
    );
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  assertQuestionBank();
  process.stdout.write(renderQuestionSeedSql());
}
