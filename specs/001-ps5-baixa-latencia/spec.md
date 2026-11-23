# Feature Specification: Baixa latência no PS5 Remote Play

**Feature Branch**: `baixa-latencia-ps5`

**Created**: 2026-11-23

**Status**: Draft

**Input**: User description: "Melhorar o código do chiaki dentro do Veyra, algo mais criativo e inteligente,
para chegar o mais perto possível de zero delay: perda sem espera, Wi-Fi sem varredura e painel de atraso."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pacote perdido não trava mais a imagem (Priority: P1)

O jogador está no PS5 pelo Veyra, numa rede que perde um pacote de vídeo de vez em quando (comum no
Wi-Fi). Hoje cada pacote perdido segura a imagem por até 16 ms esperando por ele, e os quadros
seguintes ficam presos atrás, o que aparece como tranco e atraso extra. Com a melhoria, quando o
quadro já pode ser reconstruído com as peças de correção de erro que vieram junto, a imagem segue na
hora; e quando não pode, a espera dura só o que aquela rede realmente precisa, medido ao vivo.

**Why this priority**: É a maior fonte de atraso evitável no caminho de rede que está sob nosso
controle, acontece em toda perda de pacote e não depende de hardware novo.

**Independent Test**: Uma rede simulada envia quadros a 60 por segundo com perda e reordenação
controladas; mede-se quanto tempo cada quadro fica retido no receptor além da chegada do seu último
pacote, com o comportamento antigo e com o novo.

**Acceptance Scenarios**:

1. **Given** um quadro com peças de correção suficientes e um pacote do meio perdido, **When** o resto
   do quadro chega, **Then** o quadro é liberado sem esperar pelo pacote perdido.
2. **Given** um pacote de correção perdido no fim de um quadro que já está completo, **When** os
   pacotes do quadro seguinte chegam, **Then** o quadro seguinte não espera nada pelo pacote perdido.
3. **Given** uma rede que entrega pacotes fora de ordem com atraso de até 3 ms, **When** um pacote chega
   atrasado dentro dessa faixa, **Then** ele é aproveitado (ou o quadro já foi reconstruído sem ele) e
   nenhum quadro é perdido por causa disso.
4. **Given** uma rede que nunca reordena (cabo), **When** um quadro não recuperável perde um pacote,
   **Then** a espera por ele cai com o tempo até o piso definido, em vez de ficar sempre em 16 ms.
5. **Given** a rede passa a reordenar mais do que a espera atual, **When** pacotes começam a chegar
   tarde demais, **Then** a espera volta a subir sozinha, sem passar do teto antigo.

---

### User Story 2 - Painel de atraso do PS5 (Priority: P2)

O jogador aperta o mesmo atalho que já mostra o painel do PC e do Xbox (Ctrl+Alt+Shift+S) e passa a
ver também o do PS5: quadros recebidos e decodificados por segundo, perda de pacotes, quantas perdas
foram resolvidas na hora, quanto tempo a imagem esperou por pacote e qual é a espera máxima atual.
Assim ele vê, com número, se a rede dele está atrapalhando e se a melhoria está agindo.

**Why this priority**: Sem régua não dá para provar ganho nenhum no hardware real; é o que transforma
a melhoria de P1 em algo verificável no PC do jogador.

**Independent Test**: Com valores de sessão conhecidos (fixos), o painel mostra exatamente esses
números; o que a sessão não informa aparece como traço.

**Acceptance Scenarios**:

1. **Given** uma sessão PS5 ativa, **When** o jogador aperta o atalho, **Then** o painel do PS5 aparece e
   some ao apertar de novo.
2. **Given** um número que a sessão ainda não mediu, **When** o painel é exibido, **Then** o campo
   mostra traço, nunca zero inventado.
3. **Given** perdas resolvidas na hora e perdas que esperaram, **When** o painel atualiza, **Then** as
   duas contagens aparecem separadas e o tempo total de espera bate com o registrado pela sessão.

---

### User Story 3 - Wi-Fi sem varredura durante o jogo (Priority: P3)

No Windows, a placa Wi-Fi para de tempos em tempos para procurar outras redes, e isso causa picos de
atraso. Durante uma sessão PS5, o Veyra pede ao Windows o modo de transmissão contínua da placa e
desliga essa procura; ao fim da sessão (ou se algo falhar), tudo volta como estava.

**Why this priority**: Só ajuda quem joga no Wi-Fi e só pode ser provado no PC real com Windows, mas é
barato e não tem efeito colateral fora da sessão.

**Independent Test**: Com uma placa Wi-Fi simulada, verifica-se que o pedido é feito só para placas
conectadas, que tudo é desfeito ao fim e que falhas não impedem a sessão.

**Acceptance Scenarios**:

1. **Given** um PC com Wi-Fi conectado, **When** a sessão PS5 começa, **Then** a procura de redes é
   desligada e o modo de transmissão contínua é ligado só nessa placa.
2. **Given** a sessão termina por qualquer motivo, **When** o Veyra encerra a conexão, **Then** os
   ajustes são desfeitos.
3. **Given** um PC sem Wi-Fi ou sem o serviço de Wi-Fi do Windows, **When** a sessão começa, **Then** a
   sessão abre normalmente e o registro diz que o ajuste não foi aplicado e por quê.

---

### Edge Cases

- Quadro sem nenhuma peça de correção: a perda só pode ser resolvida pela chegada do pacote; vale a
  espera adaptativa.
- Rajada de perdas maior que as peças de correção do quadro: o quadro não é recuperável; vale a espera
  adaptativa e, se expirar, o fluxo atual de quadro corrompido segue igual.
- Pacote duplicado de um já entregue: é descartado como hoje e não mexe em nada.
- Pacote que chega depois de a lacuna ter sido pulada por tempo esgotado: é descartado, conta como
  "chegou tarde demais" e faz a espera subir. Se a lacuna foi pulada pela correção de erros, ele conta à
  parte, não mexe na espera e, se chegou dentro dos 16 ms que a política antiga esperaria, volta a contar
  como recebido no relatório de perda enviado ao console.
- Virada do contador de pacotes (65535 para 0): as contas usam a comparação circular que o chiaki já
  usa.
- Início da sessão, antes de qualquer medição: a espera começa no teto antigo (16 ms) e só desce com
  evidência.
- Fila cheia (64 pacotes): o descarte atual continua valendo.
- Sessão de áudio e vibração do controle: fora do escopo, não passam por essa fila.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O receptor MUST liberar imediatamente um pacote de vídeo faltante quando o quadro a que
  ele pertence já tem pacotes suficientes para ser reconstruído pela correção de erro.
- **FR-002**: O receptor MUST tratar como dispensável um pacote faltante de um quadro que já foi
  entregue completo ou reconstruível, sem segurar os quadros seguintes.
- **FR-003**: Quando o quadro não é reconstruível, o receptor MUST esperar o pacote faltante por um
  tempo adaptativo, com piso de 2 ms e teto de 16 ms, começando no teto.
- **FR-004**: O tempo adaptativo MUST subir quando pacotes chegam depois de terem sido pulados e MUST
  descer gradualmente quando a rede passa um período sem reordenação.
- **FR-005**: Um pacote que chega fora de ordem dentro do tempo de espera vigente MUST ser entregue na
  ordem certa, como hoje.
- **FR-006**: O comportamento antigo (espera fixa de 16 ms, sem liberação por correção de erro) MUST
  continuar disponível por uma única troca de configuração em tempo de compilação.
- **FR-007**: A sessão MUST contar e expor, de forma segura entre linhas de execução: lacunas
  encontradas, lacunas resolvidas na hora pela correção de erro, lacunas resolvidas por tempo esgotado,
  pacotes que chegaram atrasados a tempo, pacotes que chegaram tarde demais, tempo total e máximo de
  espera e o tempo de espera vigente.
- **FR-008**: O Veyra MUST exibir esses números, junto com recebidos e decodificados por segundo e a
  perda de pacotes, no painel de stream do PS5, usando o mesmo atalho dos painéis de PC e Xbox.
- **FR-009**: Campos não medidos MUST aparecer como traço.
- **FR-010**: No Windows, durante a sessão PS5, o Veyra MUST desligar a procura de redes e ligar o modo
  de transmissão contínua em cada placa Wi-Fi conectada, e MUST desfazer ao encerrar, inclusive em erro.
- **FR-011**: Qualquer falha no ajuste do Wi-Fi MUST ser registrada e MUST NOT impedir a sessão.
- **FR-012**: As mudanças no chiaki MUST entrar como um novo patch numerado, aplicado depois dos quatro
  existentes, e o verificador de stage MUST aceitar o conjunto completo.
- **FR-013**: Um pacote que chega depois de o quadro ter sido refeito pela correção de erros, dentro de
  16 ms do momento em que faltou, MUST contar como recebido no relatório de perda que vai ao console (a
  política antiga o teria entregue; contá-lo como perdido faria o console baixar a qualidade à toa).

- **FR-014**: O relatório de perda ao console MUST continuar correto quando o contador de quadros de
  áudio dá a volta (65535 para 0); antes, o relatório dessa virada dizia cerca de 2^64 pacotes perdidos.
  Um quadro de áudio que chega atrasado, depois do relatório que o cobria, MUST contar como recebido a
  mais, nunca transformar o intervalo inteiro em perda.
- **FR-015**: O socket de vídeo MUST ter espaço de recepção para um quadro grande inteiro (alvo de 4 MiB,
  reduzindo pela metade enquanto o sistema recusar, nunca abaixo do valor antigo), sem mudar a janela
  anunciada ao console.
- **FR-016**: O laço que decodifica o vídeo do PS5 MUST acordar quando um quadro chega, em vez de dormir
  um intervalo fixo entre checagens; com a caixa de entrada fechada (parando ou em falha) vale o sono antigo.

### Key Entities

- **Lacuna de vídeo**: posição na sequência de pacotes de vídeo que falta quando o próximo da fila
  deveria sair; tem início (momento em que foi notada), quadro a que pertence e desfecho (chegou,
  correção de erro, tempo esgotado).
- **Quadro em trânsito**: grupo de pacotes de um quadro de vídeo; tem total de pacotes, quantos são de
  correção, quantos já foram entregues e quantos estão na fila.
- **Espera adaptativa**: valor vigente em microssegundos, com piso, teto, histórico curto de atrasos
  observados e momento da última reordenação.
- **Estatísticas de reordenação**: os contadores de FR-007, lidos pelo Veyra e mostrados no painel.
- **Ajuste de Wi-Fi da sessão**: lista de placas ajustadas e o que foi ligado ou desligado em cada uma,
  para desfazer ao fim.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em rede simulada a 60 quadros por segundo, com 1% de perda aleatória, sem reordenação e
  peças de correção suficientes, a retenção extra média por pacote perdido cai de cerca de 16 ms
  (comportamento antigo, medido no mesmo teste) para menos de 1 ms.
- **SC-002**: No mesmo cenário, nenhum quadro que o comportamento antigo entregava deixa de ser
  entregue (zero quadros a menos).
- **SC-003**: Em rede simulada com reordenação de até 3 ms e sem perda, 100% dos quadros chegam
  inteiros (pelo pacote atrasado ou pela correção de erros), sem nenhum pulo por tempo esgotado.
- **SC-004**: Em rede simulada sem reordenação e com perdas não recuperáveis, a espera vigente desce do
  teto ao piso em até 10 segundos de sessão.
- **SC-005**: Os 102 testes existentes do chiaki continuam passando, e cada teste novo falha quando o
  defeito correspondente é plantado.
- **SC-006**: O painel do PS5 mostra os valores de uma sessão conhecida sem diferença, e traço nos
  campos ausentes.
- **SC-007**: O ajuste de Wi-Fi compila para Windows e, com placa simulada, é aplicado só em placas
  conectadas e desfeito em 100% dos encerramentos, inclusive os por erro.
- **SC-008**: Em rede simulada só com reordenação de até 3 ms (sem perda), a perda informada ao console é
  a mesma da política antiga (zero); com perda real, é exatamente a perda real. Atrasos acima de 16 ms
  podem fazer a nova informar um pouco mais que a antiga (medido pelo crítico: +0,31 ponto percentual com
  atrasos de até 20 ms), porque a fila travada da antiga esticava a espera de buracos seguidos.

- **SC-009**: Numa rajada de 300 pacotes (420 kB) que chega sem ninguém ler, o buffer antigo (100 kB)
  guarda 71 pacotes e o novo guarda os 300 (medido em macOS; em sistema que limita o buffer o teste se
  declara pulado).
- **SC-010**: No relatório que cobre a virada do contador, 10 quadros recebidos dão 0 perdidos; com um
  quadro realmente perdido na virada, dá 1. Dez quadros recebidos mais um atrasado do relatório anterior
  dão 11 recebidos e 0 perdidos (antes: 10 perdidos).
- **SC-011**: A espera por vídeo acorda na chegada do quadro (bem antes do tempo limite), não perde
  aviso de quadro que já estava na fila, respeita o tempo limite e avisa na hora quando a caixa fechou.

## Assumptions

- Os índices de pacote de vídeo são contíguos dentro e entre quadros, e o primeiro pacote de um quadro
  é o índice do pacote menos o seu índice de unidade; o próprio chiaki já assume isso ao iniciar a fila.
- A correção de erro do chiaki reconstrói um quadro com quaisquer pacotes em quantidade igual ao número
  de pacotes de dados do quadro.
- O ganho real (PS5, rede e PC do jogador) só pode ser medido no notebook do usuário; esta feature
  entrega a lógica testada em simulação e o painel que permite medir lá.
- O PC do jogador roda Windows 10 ou 11, onde as funções de Wi-Fi usadas existem.
- Compilar o Veyra inteiro exige o ambiente Windows dele; aqui se compila e testa o chiaki completo e as
  partes portáveis do Veyra, e o código só de Windows é compilado contra cabeçalhos do Windows.
