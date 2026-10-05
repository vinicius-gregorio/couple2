-- CreateEnum
CREATE TYPE "QuestionCategory" AS ENUM ('FUN', 'DEEP', 'MEMORIES', 'FUTURE', 'DAILY_LIFE');

-- CreateTable
CREATE TABLE "questions" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "locale" TEXT NOT NULL DEFAULT 'pt-BR',
    "category" "QuestionCategory" NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "questions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "couple_questions" (
    "id" TEXT NOT NULL,
    "coupleId" TEXT NOT NULL,
    "questionId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "unlockedAt" TIMESTAMP(3),
    "dailyNotifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "couple_questions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "question_answers" (
    "id" TEXT NOT NULL,
    "coupleQuestionId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "question_answers_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "question_answers_text_len" CHECK (char_length("text") >= 1 AND char_length("text") <= 1000)
);

-- CreateIndex
CREATE UNIQUE INDEX "questions_slug_key" ON "questions"("slug");

-- CreateIndex
CREATE INDEX "couple_questions_coupleId_questionId_idx" ON "couple_questions"("coupleId", "questionId");

-- CreateIndex
CREATE UNIQUE INDEX "couple_questions_coupleId_date_key" ON "couple_questions"("coupleId", "date");

-- CreateIndex
CREATE UNIQUE INDEX "question_answers_coupleQuestionId_userId_key" ON "question_answers"("coupleQuestionId", "userId");

-- AddForeignKey
ALTER TABLE "couple_questions" ADD CONSTRAINT "couple_questions_coupleId_fkey" FOREIGN KEY ("coupleId") REFERENCES "couples"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "couple_questions" ADD CONSTRAINT "couple_questions_questionId_fkey" FOREIGN KEY ("questionId") REFERENCES "questions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "question_answers" ADD CONSTRAINT "question_answers_coupleQuestionId_fkey" FOREIGN KEY ("coupleQuestionId") REFERENCES "couple_questions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- (coupleId, questionId) is indexed, not UNIQUE. QuestionsService refuses a
-- repeat until every active question has been used. Acceptance criterion 6
-- then reuses the least-recent question; a hard unique constraint would turn
-- that fallback into an insert error.

-- Idempotent pt-BR bank. Running this INSERT twice does not create duplicates.
INSERT INTO "questions" ("id", "slug", "text", "locale", "category", "active", "createdAt")
VALUES
  ('fb5e1a1e-be39-8cdf-6a29-1f663525805e', 'fun-001', 'Se o nosso casal fosse um filme, qual seria o título?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('0bc9156c-a2a2-817b-3d7e-27e8a50036e0', 'fun-002', 'Qual música descreve a gente hoje?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('6b990963-72ea-d6eb-c528-59b0af28b531', 'fun-003', 'Se a gente tivesse um restaurante só nosso, qual seria o prato da casa?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('24093909-7eb5-e6d7-01dd-4550c08b15b1', 'fun-004', 'Se a gente trocasse de corpo por um dia, o que você faria primeiro?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('66901877-9a77-c8a1-e8f2-de37b3f9568b', 'fun-005', 'Qual emoji combina mais com o nosso relacionamento?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('687dc961-18d8-c224-ef86-6b0881761845', 'fun-006', 'Qual seria o nome do nosso barco, se tivéssemos um?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('4c2abc59-c657-041c-1aab-6456dbb4739a', 'fun-007', 'Que superpoder você me emprestaria por uma tarde?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('9fe3026b-7bbc-97b5-8c01-c0721d02de44', 'fun-008', 'Qual série a gente deveria começar juntos esta semana?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('be249d11-94cc-c565-af39-6617db4ee597', 'fun-009', 'Se a gente formasse uma banda, qual seria o nome?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('e57b192e-399b-1440-5f74-f8932fe01126', 'fun-010', 'Qual comida você nunca recusa quando eu ofereço?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('c4565199-18bc-26f2-d3c0-207e0203d1eb', 'fun-011', 'Qual é a nossa piada interna favorita?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('cf7047a5-efbc-a3cc-02e8-2581363adca8', 'fun-012', 'Se o dia de hoje virasse desenho animado, qual seria a cena?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('3a6f508d-49d1-e1bf-59ae-473a494bdd60', 'fun-013', 'Qual fantasia de carnaval a gente usaria lado a lado?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('98008cd8-ae79-6944-3745-896d127b9327', 'fun-014', 'Que talento inútil você gostaria que eu tivesse?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('4fef9bb0-e668-812a-6291-1b3e6f01b2e0', 'fun-015', 'Qual seria o nosso grito de guerra antes de uma viagem?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('fd63c7c8-77ff-cabe-4eaf-9992632fe3ba', 'fun-016', 'Se a gente abrisse um café, o que teria no cardápio?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('45793261-25c7-f428-5ca2-be618f40639f', 'fun-017', 'Qual animal representa melhor o nosso casal?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('6cf6685c-3516-3a77-f364-1f2b145beb13', 'fun-018', 'Que apelido secreto você me daria hoje?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('7fff3104-146c-b745-0891-7f4d86f67aaf', 'fun-019', 'Qual seria a trilha sonora do nosso café da manhã?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('45a19f3c-849b-5d4e-f491-e20289cbd1e1', 'fun-020', 'Se a gente ganhasse um fim de semana sem celular, o que faríamos?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('4ae7d7f9-b738-bb4b-ddcb-48a67b73d7ff', 'fun-021', 'Qual sobremesa conta a história da gente?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('bfd0465e-b361-c50b-8561-5b9c29723513', 'fun-022', 'Que personagem de filme eu seria, segundo você?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('5f81e04b-9515-9da1-39d7-af32a8d53e87', 'fun-023', 'Qual seria o nosso esporte olímpico imaginário?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('9eacfda9-39dc-b530-3f3b-8ddccfee612b', 'fun-024', 'Se a nossa casa tivesse um mascote oficial, qual seria?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('7ef1f599-5bc9-fd7c-4029-775a85a1e201', 'fun-025', 'Qual meme descreve a gente nesta semana?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('d90df6eb-4582-f233-9ad6-bbb0e41f1d57', 'fun-026', 'Que aula maluca a gente faria juntos só pela diversão?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('3fd5c73d-beff-3662-5c17-4c80a950f734', 'fun-027', 'Qual seria o nome da nossa playlist de domingo?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('ca465ff9-3d06-78cd-c2fa-6d76b304de57', 'fun-028', 'Se a gente fosse um sabor de sorvete, qual seria?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('6ce624fd-a463-8efe-cd9a-c20bd2ae6fa7', 'fun-029', 'Que brincadeira de infância a gente deveria repetir?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('cc313bfe-882b-3ee2-b8d3-895c51882a16', 'fun-030', 'Qual seria o nosso recorde mundial mais bobo?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('3e49ae30-c916-96d6-16c0-c2fe80cbcad4', 'fun-031', 'Se eu te desse um troféu hoje, o que estaria escrito nele?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('942fad6e-b3d3-432e-0b6c-f97217e7a86a', 'fun-032', 'Qual filme a gente precisa rever rindo junto?', 'pt-BR', 'FUN', true, CURRENT_TIMESTAMP),
  ('2de860db-064f-3cbe-c939-a38de485a6da', 'memories-001', 'Qual foi o momento em que você pensou que queria ficar comigo?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('5a719269-1cee-aecc-df22-47c129785e88', 'memories-002', 'Qual detalhe do nosso primeiro encontro você ainda lembra?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('ac477e91-b38b-dca3-0cd9-978d0d60bb67', 'memories-003', 'Qual passeio você repetiria sem mudar nada?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('be62f830-194a-0fa6-02ea-72c250e3fd08', 'memories-004', 'Qual recado meu você guardou?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('b731a672-b035-0894-1831-404fdf3bea0b', 'memories-005', 'Qual foto nossa você mostraria para alguém que acabou de te conhecer?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('37060c69-a654-1729-aebb-030bf55700cd', 'memories-006', 'Qual foi a primeira coisa que você admirou em mim?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('41ad3212-3c49-263f-b3a1-aa7d91032241', 'memories-007', 'Qual dia comum nosso virou uma lembrança boa?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('cf22f0d2-3eeb-171b-3d8f-6b09ea4dac83', 'memories-008', 'Qual comida está ligada a um dia nosso?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('82cadd74-78dd-af19-2549-fe22fbe315ce', 'memories-009', 'Qual música te leva de volta para a gente?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('7dfe78a6-8b60-e4ae-a924-924ae1225a2a', 'memories-010', 'Qual foi o presente mais simples que você ainda lembra?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('797a34ee-eca8-7d4f-a1dc-bbcb0b9bbcef', 'memories-011', 'Qual conversa nossa você gostaria de ouvir de novo?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('c9ffd945-4ae5-3431-ec7d-79ba328718fa', 'memories-012', 'Qual lugar da cidade é nosso?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('fb16c76b-d076-6e42-8520-e45fdcddfe73', 'memories-013', 'Qual foi a primeira risada que você lembra da gente?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('e8ce7cf2-0408-0df4-59da-e068ae7f85f6', 'memories-014', 'Qual plano que deu errado acabou ficando bom?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('19452302-0532-b566-bac0-f2078144aaee', 'memories-015', 'Qual história nossa você contaria num jantar?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('67b30164-564b-13f2-1c4e-acb5f808092e', 'memories-016', 'Qual cheiro te lembra a gente?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('b63fd4f8-731d-65de-895f-15377b3bc6d1', 'memories-017', 'Qual dia difícil a gente atravessou junto e você ainda guarda com carinho?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('77e4c637-afd4-bbbc-12b3-04bb32afbb1c', 'memories-018', 'Qual mensagem antiga você releria hoje?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('c9407c60-3a9e-7b25-cc6d-9b988c3a03e4', 'memories-019', 'Qual foi o primeiro apelido entre a gente?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('25c7aeca-b8cc-4e37-eff1-1a093ce54cba', 'memories-020', 'Qual passeio curto você guarda com carinho?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('4c6ae637-388d-8293-a5d9-fcb5453d617d', 'memories-021', 'Qual tradição pequena a gente já criou sem perceber?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('ba5e44eb-ffef-dc36-ec28-98d82e0b644c', 'memories-022', 'Qual foi a última vez que a gente se surpreendeu juntos?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('48b29037-dbc8-b4f1-24e3-7288c0586ab0', 'memories-023', 'Qual roupa minha você associa a uma lembrança?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('ac3e2a1f-fc34-0969-e07f-cc83a33d96ee', 'memories-024', 'Qual foi um sim seu que mudou o nosso caminho?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('0925d5eb-7e73-103c-13ce-0c01858e5a3c', 'memories-025', 'Qual dia de chuva nosso você lembra?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('dd3ea694-8a94-6225-cd73-cc85744b4bbf', 'memories-026', 'Qual frase minha ficou com você?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('a4c5965e-3ad0-b1fb-69d7-93d6dc03ef39', 'memories-027', 'Qual foi o nosso primeiro a gente em vez de eu?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('2d4228ae-fd8a-cfa8-9b4d-47b241f63d42', 'memories-028', 'Qual lugar você quer revisitar só pela memória?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('ff3f28e7-a727-f6e2-74e6-499676931071', 'memories-029', 'Qual gentileza pequena eu fiz e você não esqueceu?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('418ec634-dff2-a446-d8b4-f80d63959a1e', 'memories-030', 'Qual festa, filme ou show a gente viveu junto?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('94ccaee7-36d3-6888-63ad-8505dddc027a', 'memories-031', 'Qual foi o momento em que você se sentiu em casa comigo?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('591ced59-6158-8351-7fa4-865c9a7bdbe7', 'memories-032', 'Qual lembrança nossa você contaria daqui a vinte anos?', 'pt-BR', 'MEMORIES', true, CURRENT_TIMESTAMP),
  ('9a4c38c7-3683-26b7-c24d-71cda8c98aea', 'future-001', 'Que viagem a gente ainda precisa fazer juntos?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('f02acb00-a058-7bb3-3aff-e1ba5e97477c', 'future-002', 'Como você imagina um domingo nosso daqui a cinco anos?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('b87fd7fe-3493-a3ab-f3e2-47a4b3fe8cdb', 'future-003', 'Qual hábito a gente poderia começar neste mês?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('6a33c1aa-6fa8-9e8d-095c-b384111759ae', 'future-004', 'Que canto da casa você sonha para a gente?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('a97c3718-b065-52e0-1968-67be5f3b35bf', 'future-005', 'Qual cidade você gostaria de descobrir comigo?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('ad460343-8698-c6c2-ec9e-2317d31748ef', 'future-006', 'Que tradição nova a gente inventa a partir de agora?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('258b5fce-b058-e356-f897-269a1e05ff5d', 'future-007', 'O que você quer aprender junto comigo?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('52f9d216-5233-0dde-39f4-da3b604c6f01', 'future-008', 'Qual projeto pequeno a gente pode terminar neste ano?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('b6fe21f6-e635-0882-9a5b-d9bde1be9a07', 'future-009', 'Como você quer comemorar o nosso próximo aniversário de casal?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('7e5dc61b-3902-d66b-8be9-b453be8b0385', 'future-010', 'Que receita a gente deveria dominar juntos?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('986f8f23-4ca9-ead2-7eb2-124faa9601f2', 'future-011', 'Qual lugar perto da gente ainda está inexplorado?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('3360b582-727e-ff51-2fd2-e3168d920125', 'future-012', 'O que você quer que a gente proteja na nossa rotina?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('140d6c45-ec91-7f0e-ea64-eaebd4398b80', 'future-013', 'Qual sonho seu eu ainda conheço pouco?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('e0f43c92-fbd2-7299-2454-512eb8bd60be', 'future-014', 'Que fim de semana temático a gente poderia planejar?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('df31c50f-9dcc-a495-dd64-f1df33303234', 'future-015', 'Como você imagina as nossas manhãs daqui a um tempo?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('d42481a7-8765-3069-99f1-d1172a295db6', 'future-016', 'Qual habilidade você quer que a gente pratique lado a lado?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('91bfef5c-6bde-d9a9-01a8-642fbf573ef8', 'future-017', 'Que foto a gente ainda não tirou?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('9c668f09-2ff2-68ac-27e3-2ca9e81bf31d', 'future-018', 'Qual meta de um ano cabe na nossa vida real?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('2a92b070-e513-6aa4-d98b-2701c0f94e10', 'future-019', 'Onde você gostaria de acordar nas próximas férias?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('0d982dfb-352c-baaf-9c08-86062af669f4', 'future-020', 'Que livro ou curso a gente pode fazer em dupla?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('1a003806-832a-a3e1-02bd-ecf748afe7d2', 'future-021', 'Qual combinado simples deixaria a semana mais leve?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('80fcaf6d-b697-af73-b02c-7bd7d72e4016', 'future-022', 'Que celebração pequena a gente pode criar todo mês?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('5b487a01-703e-ded8-dbc5-961303130dca', 'future-023', 'Como você quer que a gente se apoie num ano ocupado?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('ce562405-d8a2-da4b-0a33-c9f4bb052e73', 'future-024', 'Qual lugar da casa a gente poderia cuidar juntos?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('d1246389-a826-4c93-9d64-2836a101f7d7', 'future-025', 'Que experiência ao ar livre você quer viver comigo?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('6804a17f-6e70-3593-4802-fcc1111137a2', 'future-026', 'Qual plano adiado a gente tira do papel?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('bdc4f3ba-bc1a-1332-905d-3b2ca078f0c1', 'future-027', 'O que você quer que continue igual entre a gente?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('797fa2fa-9dfb-fd67-2509-2ee751f409a4', 'future-028', 'Qual idioma, prato ou dança a gente experimenta juntos?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('9a417763-547e-be14-abf0-70aa84e02d19', 'future-029', 'Como seria um dia perfeito e possível no próximo mês?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('af865152-c8a5-7995-4d57-1a96c8f3dafa', 'future-030', 'Que carta a gente poderia escrever para abrir daqui a um ano?', 'pt-BR', 'FUTURE', true, CURRENT_TIMESTAMP),
  ('148e4f45-97f0-1012-320e-c658d622dbf3', 'daily-001', 'O que deixou o seu dia mais leve hoje?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('5559f7f8-c55c-75f3-58e3-b1604eee03e6', 'daily-002', 'Qual foi o melhor pedaço do seu dia até agora?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('867cac0f-6b55-5491-8c00-dc387d6a7f23', 'daily-003', 'O que você precisa de mim nesta semana, na prática?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('56421451-9f3e-c69f-a18a-02a645a00b66', 'daily-004', 'Qual tarefa chata a gente pode dividir?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('a169de47-cfb6-a2db-2d99-0a1ab65e4692', 'daily-005', 'O que você quer jantar quando não quiser decidir?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('adf22d41-a902-8ee5-e966-ca1f4c610d81', 'daily-006', 'Qual horário do dia é mais seu, e como eu respeito isso?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('b12a3da4-dfa1-b250-c93b-ba1f92edc713', 'daily-007', 'O que te recarrega em vinte minutos?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('02f753cb-1985-1496-fb6c-8010f5bb4ce6', 'daily-008', 'Qual pequena gentileza eu posso fazer amanhã?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('e999d7b9-7396-e2b3-7163-b6e6715b70fe', 'daily-009', 'O que está ocupando a sua cabeça hoje?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('5dc805f1-9518-7cdd-a2af-30dfaa06d0dd', 'daily-010', 'Qual parte da rotina a gente poderia simplificar?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('08e776ed-964a-1d3c-9b3a-22e4535b0b84', 'daily-011', 'Como você prefere receber cuidado num dia corrido?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('43d04ca8-9dda-bb5e-cef3-53f696002686', 'daily-012', 'O que você quer comemorar, mesmo que seja pequeno?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('4e72dad9-af99-53b2-4bd9-ec04800adc90', 'daily-013', 'Qual combinado de celular deixaria a gente mais presente?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('cadebb44-d353-4623-cadf-1777b0ac8101', 'daily-014', 'O que você está evitando e eu posso ajudar a começar?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('acf56eaa-6efc-ee8c-70cb-93cf13fe6de5', 'daily-015', 'Qual é o seu não desta semana, para proteger o descanso?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('987d3369-4857-729b-a899-5755bd863e5c', 'daily-016', 'O que te fez sorrir hoje fora de casa?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('4844af29-dcd1-d163-6872-2130a9052ed9', 'daily-017', 'Qual refeição a gente transforma em encontro esta semana?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('ddf19e17-ff48-0951-ddfb-22ae322469d7', 'daily-018', 'O que você quer que eu pergunte mais vezes?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('0af27d2b-112d-6b6b-8a7e-07ecdcedfb8e', 'daily-019', 'Qual canto da casa está pedindo atenção?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('64d516fd-8c30-f658-683b-db625d7c0c5e', 'daily-020', 'Como foi o seu sono, de verdade?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('274bf5ac-d3eb-a30d-f7d2-ef79444e0dc4', 'daily-021', 'O que você quer fazer hoje à noite, do jeito mais simples?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('b4eedc3d-925c-8f2f-e0dd-1da3eea5389b', 'daily-022', 'Qual assunto prático a gente resolve em dez minutos?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('fc0b7a0b-fe1d-765b-adcd-9dcb2319f350', 'daily-023', 'O que te cansou hoje e já pode ficar do lado de fora?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('f111afe4-df79-b647-be6a-6798262edc08', 'daily-024', 'Qual café, praça ou padaria merece uma visita nossa?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('3a0b3d79-9125-8e7d-9b6f-9d1f8f18fc02', 'daily-025', 'O que você quer ouvir de mim num dia comum?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('179fb541-7e21-25a6-dcf3-c3dcf4d914e9', 'daily-026', 'Qual responsabilidade a gente pode revezar melhor?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('6f7e3c30-4227-f6f7-33ee-cb3afe9e46a2', 'daily-027', 'O que você está com vontade de cozinhar ou pedir?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('03c31057-c992-e955-fd63-7817b62c91d6', 'daily-028', 'Qual pausa curta caberia no nosso dia de amanhã?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('598506c3-fb29-85f3-867f-0b0c292603dd', 'daily-029', 'O que você quer largar na porta antes de chegar em casa?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('4c2eefab-6029-2782-7d65-b774c483a98d', 'daily-030', 'Qual detalhe do meu dia você gostaria de saber hoje?', 'pt-BR', 'DAILY_LIFE', true, CURRENT_TIMESTAMP),
  ('177e2d4b-b259-f874-356c-1b9228c5ae17', 'deep-001', 'O que em mim te faz sentir segurança?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('5747409d-299e-a939-a1c9-c364c98b0b98', 'deep-002', 'Qual valor nosso você não abriria mão?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('beb9813b-74de-ea3b-0b87-5afe0a6820b1', 'deep-003', 'Quando você se sente mais amado por mim?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('df983f16-409e-dfa7-ab30-ec9acbf746ad', 'deep-004', 'O que você aprendeu sobre si desde que a gente está junto?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('739c2845-de8c-8599-ca01-06dd827d6324', 'deep-005', 'O que casa significa para você quando pensa na gente?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('1800ef99-f7e1-9dd7-7722-35c81518ed23', 'deep-006', 'Qual parte da sua história você gosta de compartilhar comigo?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('39385e8f-5283-5caf-dc03-02df4d9708cc', 'deep-007', 'Como você pede ajuda quando precisa, e como eu posso perceber?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('5dc5aa0c-81d3-bce8-d098-685b623da577', 'deep-008', 'O que você admira em mim e ainda não disse em voz alta?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('e02582e8-a3d0-319d-3379-ff4a0343a9dc', 'deep-009', 'Qual combinado deixa a gente mais leve depois de um desentendimento?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('c70c9ff2-dc54-e07b-2916-007a3e0d9697', 'deep-010', 'O que você quer que eu entenda sobre o seu jeito de amar?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('389e2d9a-ce08-e1b5-e5b2-bce7266e04d3', 'deep-011', 'Qual sonho seu merece mais espaço na nossa conversa?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('862f3f35-196b-3a0b-568c-069a134bbcb6', 'deep-012', 'Quando você se sente mais você, ao meu lado?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('d19c6ba1-62c5-b266-ad8f-456ea7678c9b', 'deep-013', 'O que gratidão parece, concretamente, entre a gente?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('01c566ba-e928-4c6f-f6ee-0c1a4296d98e', 'deep-014', 'Qual limite seu eu deveria conhecer melhor?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('effe1311-016b-bcb3-3623-6364071433ee', 'deep-015', 'O que você espera que a gente ainda descubra um sobre o outro?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP),
  ('8665ee35-7c5c-b69e-17bd-de920062f9fc', 'deep-016', 'Qual cuidado pequeno faz você se sentir escolhido?', 'pt-BR', 'DEEP', true, CURRENT_TIMESTAMP)
ON CONFLICT ("slug") DO NOTHING;
