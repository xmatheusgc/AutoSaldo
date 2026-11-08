# AutoSaldo

**Especificação do MVP para implementação com Gemini**  
**Identificador do projeto Flutter e do repositório** · `autosaldo`

O AutoSaldo ajuda um vendedor autônomo de carros usados e seminovos a responder, pelo iPhone, quanto investiu em cada carro, quanto ganhou na venda e quanto ainda tem a receber. O MVP atende um vendedor e, se necessário, um segundo operador com acesso ao mesmo estoque.

## 1. Stack e implantação

| Parte | Escolha | Aplicação |
| --- | --- | --- |
| Interface | Flutter Web e Dart | Interface responsiva, em português do Brasil, com prioridade para Safari no iPhone. |
| Autenticação | Firebase Authentication | E-mail e senha. Criar as contas autorizadas pelo console e oferecer recuperação de senha pelo Firebase Auth. |
| Banco | Cloud Firestore Standard | Veículos, despesas, vendas e recebimentos. Acesso direto pelo FlutterFire, com autorização nas Firestore Security Rules. |
| Hospedagem | Firebase Hosting | Publicar o conteúdo estático de `build/web` por HTTPS no endereço `web.app` do projeto. Se usar rotas sem hash, configurar o redirecionamento das rotas da SPA para `index.html`. |
| Desenvolvimento | FlutterFire CLI, Firebase CLI e Local Emulator Suite | Configurar o Firebase para Web e validar autenticação e regras com dados fictícios antes de usar os dados do vendedor. |

Manter o projeto no **Spark**, dentro das franquias gratuitas. O MVP usa somente dados estruturados, sem upload de fotos ou documentos, Base64, Cloud Storage ou Cloud Functions. A eventual inclusão de anexos será uma etapa separada, com arquivos privados no Storage e metadados no Firestore. A ativação do Storage exigirá avaliar o Blaze nessa etapa.

Configurar nome, ícone e manifesto web. Validar no iPhone o fluxo **Safari → Compartilhar → Adicionar à Tela de Início → Abrir como App da Web**. O MVP funciona conectado. Se a conexão cair durante uma gravação, manter os dados digitados e sinalizar que o registro ainda não foi confirmado pelo servidor.

## 2. Ficha do veículo

O cadastro inicial pede **marca, modelo, placa, data da compra e valor pago**. Versão, preço anunciado e observações são opcionais. A documentação pode ser preenchida depois. A lista deve permitir busca por placa, marca, modelo ou RENAVAM.

| Campo do CRLV-e na imagem de referência | Campo no app | Regra |
| --- | --- | --- |
| Código RENAVAM | `renavam` | Texto opcional com 11 dígitos quando preenchido. Preservar zeros à esquerda. |
| Placa | `plate` | Texto obrigatório. Normalizar para maiúsculas e remover espaço e hífen. Aceitar padrão antigo `ABC1234` e Mercosul `ABC1D23`. |
| Exercício | `licensingYear` | Ano de quatro dígitos, opcional. Registrar o exercício impresso no CRLV-e. |
| Ano fabricação | `manufactureYear` | Ano de quatro dígitos, opcional. |
| Ano modelo | `modelYear` | Ano de quatro dígitos, opcional e independente do ano de fabricação. |
| Número do CRV | `crvNumber` | Texto numérico opcional. Preservar zeros à esquerda e manter separado do código de segurança do CRV. |

Adicionar o campo **Situação da documentação**, preenchido pelo operador, com as opções **A verificar**, **Em dia** e **Com pendência**. Permitir uma observação curta para explicar a pendência. O exercício do CRLV é informativo. A ficha não deve concluir automaticamente que a documentação está em dia. Registrar apenas os campos listados, sem copiar a imagem, ler seu QR Code ou consultar órgãos de trânsito.

Cada ficha representa **um ciclo de compra e venda**. Se o vendedor recomprar um carro que já vendeu, cadastrar um novo ciclo e preservar a venda anterior. Avisar quando uma placa ou um RENAVAM já aparecer em outro registro em estoque.

## 3. Regras financeiras

### Compra e despesas

- A compra cria um carro **Em estoque**. Para o MVP, considerar a compra integralmente paga na data da compra. Parcelamento da compra e contas a pagar ficam para uma próxima etapa.
- Toda despesa pertence a um veículo e registra valor positivo, data do pagamento, categoria e descrição opcional. Categorias iniciais: oficina, peças, documentação, transporte, anúncio, comissão e outros.
- Lançar somente despesas pagas. Permitir gasto posterior à venda, como uma comissão ou reparo assumido pelo vendedor. Esse gasto reduz o lucro do carro e entra no caixa no mês em que foi pago.
- A compra já compõe o custo do carro. A interface deve orientar o operador a lançar despesas adicionais nessa seção.
- **Custo total do veículo** = valor pago na compra + despesas válidas do veículo.
- Enquanto estiver em estoque, mostrar **Total investido**. Com preço anunciado preenchido, mostrar também **Lucro estimado** = preço anunciado − custo total. Mostrar o sinal quando houver prejuízo estimado.

### Venda e recebimentos

- Registrar a data da venda e o valor final negociado. Confirmar o resumo antes de gravar. A data da venda deve ser igual ou posterior à data da compra. Compra, venda e despesas pagas não aceitam datas futuras.
- Cada ciclo admite uma venda ativa. Depois de registrada, o carro passa para **Vendido**, mesmo que o comprador ainda deva parte do valor.
- Registrar cada entrada recebida com valor e data. Oferecer o atalho **Receber total na venda** para pagamento à vista. Recebimentos podem ser parciais e em datas diferentes. Neste MVP, a data deve ser igual ou posterior à da venda e não pode estar no futuro. Sinal antecipado, permuta e consignação ficam para outra etapa.
- A soma recebida pode chegar até o valor da venda. Ao reduzir o valor negociado em uma correção, exigir que ele continue maior ou igual ao já recebido. Uma correção da data da venda também deve preservar a validade das datas dos recebimentos.
- **Lucro por carro vendido** = valor negociado − custo total. **Saldo a receber** = valor negociado − total recebido.
- Exibir **Em aberto**, **Parcial** ou **Quitado** conforme o total recebido. Tratar um resultado negativo como **Prejuízo**.
- Permitir corrigir ou estornar lançamentos com confirmação. Para cancelar uma venda e retornar o carro ao estoque, exigir o estorno prévio dos recebimentos registrados, se houver. Estorno no app corrige o registro financeiro e não executa devoluções bancárias. Evitar excluir em cascata o histórico.

### Resumo mensal

| Indicador | Regra |
| --- | --- |
| Lucro dos carros vendidos no mês | Somar o lucro por carro pela **data da venda**, incluindo gastos válidos lançados posteriormente. Um gasto tardio pode alterar o lucro histórico daquele mês. |
| Entradas no mês | Somar recebimentos válidos pela **data do recebimento**, inclusive de carros vendidos em meses anteriores. |
| Saídas no mês | Somar compras pela **data da compra** e despesas válidas pela **data do pagamento**. |
| Saldo do mês | Entradas do mês − saídas do mês. Mostrar como movimento do período, sem pressupor saldo bancário inicial. |
| Investido no estoque atual | Somar custo de todos os carros que ainda estão em estoque, independentemente do filtro mensal. |
| A receber hoje | Somar o saldo das vendas em aberto ou parciais, independentemente do filtro mensal. |

**Exemplo.** Um carro comprado por R$ 35.000, com R$ 2.000 em despesas, tem custo de R$ 37.000. Vendido por R$ 42.000, gera lucro de R$ 5.000. Se o vendedor receber R$ 40.000 no mês da venda e R$ 2.000 no mês seguinte, o lucro continua no mês da venda e o caixa registra as entradas nos respectivos meses. Se houver uma comissão de R$ 300 paga depois, o lucro da venda passa a R$ 4.700 e a saída de R$ 300 entra no mês do pagamento.

## 4. Modelo de dados e integridade

Usar um espaço de trabalho compartilhado. O segundo operador, se houver, tem os mesmos acessos ao estoque e ao financeiro. Cada pessoa usa sua própria conta.

| Caminho no Firestore | Conteúdo principal |
| --- | --- |
| `workspaces/{workspaceId}` | Nome do espaço de trabalho. |
| `workspaces/{workspaceId}/members/{uid}` | Associação de um UID autorizado ao espaço. A associação é administrada fora do app. |
| `workspaces/{workspaceId}/vehicles/{vehicleId}` | Ficha, dados da compra, preço anunciado opcional e venda ativa, quando houver. A venda guarda ID, data, valor em centavos e recebimentos do ciclo. |
| `workspaces/{workspaceId}/expenses/{expenseId}` | ID do veículo, valor em centavos, data do pagamento, categoria, descrição opcional e estado válido ou estornado. |

- Guardar valores monetários como **inteiros em centavos**. Interpretar o texto digitado conforme o padrão brasileiro e formatar em BRL. Usar funções Dart testáveis para calcular os indicadores a partir dos registros, sem persistir totais derivados por padrão.
- Guardar datas de negócio como dias civis `AAAA-MM-DD`, com referência a `America/Sao_Paulo`. Usar timestamps do servidor para campos técnicos como `createdAt` e `updatedAt`. Registrar também o UID responsável pelas alterações e validar nas regras que o UID de edição corresponde à sessão.
- Usar IDs estáveis para lançamentos. Em uma nova tentativa da mesma gravação, reutilizar o ID. Desabilitar o envio repetido enquanto a operação estiver pendente.
- Manter os poucos recebimentos do MVP junto da venda no documento do veículo. Registrar venda, recebimento ou correção em transação, lendo o estado atual para verificar valores, datas e a existência de venda ativa. Se a edição conflitar com outra alteração, exibir o estado atualizado antes de pedir nova confirmação. Preservar os dados digitados em caso de falha.
- Preservar recebimentos estornados e vendas canceladas como histórico. Ao cancelar, mover o registro anterior para o histórico e remover a venda ativa na mesma transação. O status do veículo deriva da presença da venda ativa. O status financeiro deriva dos recebimentos válidos.
- Negar acesso por padrão. Nas Security Rules, exigir sessão autenticada e associação ao espaço para acessar veículos e despesas. Bloquear a alteração de associações pelo cliente e impedir gravação de despesa sem veículo correspondente no mesmo espaço. Validar estrutura, tipos, campos permitidos e valores básicos também nas regras. Usar validação na interface para orientar o operador. A autenticação por si só não concede acesso.
- Usar estrutura Flutter simples por funcionalidade, com widgets para apresentação, funções de domínio para cálculo e repositórios para acesso ao Firebase. Manter os cálculos fora da UI e versionar `firebase.json`, `firestore.rules` e os índices necessários.

## 5. Telas e fluxo no iPhone

| Tela | Conteúdo e ação principal |
| --- | --- |
| Login | E-mail, senha, recuperação de senha e mensagem clara quando a conta não tem acesso ao espaço. |
| Estoque | Busca, filtros **Em estoque** e **Vendidos**, custo por carro e ação **Cadastrar veículo**. |
| Ficha do veículo | Resumo financeiro, documentação, despesas e recebimentos. Ações **Lançar despesa**, **Registrar venda** ou **Registrar recebimento**, conforme o estado. |
| Resumo | Seletor de mês, indicadores financeiros e exportação CSV de veículos, despesas e recebimentos. |

Priorizar formulários curtos com rótulos visíveis, teclado adequado ao tipo de dado e mensagens próximas do campo inválido. Mostrar estados de lista vazia, carregamento, salvamento e falha. Manter legíveis o total investido, o lucro e o saldo a receber, inclusive sem depender de cor.

## 6. Ordem de implementação e critérios de aceite

1. **Configuração.** Usar as skills oficiais do Firebase para setup, Auth, Firestore Standard, regras e Hosting. Usar `flutterfire configure` para registrar a plataforma Web e instalar `firebase_core`, `firebase_auth` e `cloud_firestore`. Configurar os emuladores para desenvolvimento. [Skills oficiais do Firebase](https://firebase.google.com/docs/ai-assistance/agent-skills) · [Configuração do FlutterFire](https://firebase.google.com/docs/flutter/setup)
2. **Primeiro fluxo.** Implementar acesso restrito, cadastro e ficha. Confirmar que as duas contas autorizadas enxergam os mesmos dados, que uma conta externa não consegue ler ou gravar diretamente no Firestore e que zeros à esquerda sobrevivem à gravação e à edição. [Regras do Firestore](https://firebase.google.com/docs/firestore/security/get-started)
3. **Financeiro.** Implementar despesas, venda, recebimentos e correções. Reproduzir o exemplo desta especificação. Testar também venda com prejuízo, gasto posterior à venda, reenvio da mesma gravação e tentativa simultânea de registrar recebimentos que, somados, excedam a venda. [Transações no Firestore](https://firebase.google.com/docs/firestore/manage-data/transactions)
4. **Resumo e publicação.** Conferir os totais, os filtros e a exportação CSV em UTF-8. Indicar no app que o CSV é um extrato para planilha. Executar `flutter analyze`, `flutter test` e `flutter build web`. Publicar no Firebase Hosting após validar as regras e testar login, cadastro, gravação e abertura pela Tela de Início no iPhone. Documentar no README como configurar, rodar e publicar. [Firebase Hosting](https://firebase.google.com/docs/hosting/quickstart) · [Adicionar um app da web à Tela de Início](https://support.apple.com/en-in/guide/iphone/iphea86e5236/ios)
