# AutoSaldo 🚗💰

Aplicativo de controle de estoque e gestão financeira desenvolvido especificamente para vendedores autônomos e pequenos revendedores de veículos usados e seminovos, com experiência prioritária para Safari no iPhone (PWA) e navegadores modernos.

---

## 1. Visão Geral e Recursos

O **AutoSaldo** permite ao vendedor acompanhar pelo celular:
- **Quanto investiu em cada veículo** (custo de compra + despesas pagas com mecânica, peças, documentos, transporte, anúncio, comissões).
- **Quanto lucrou na venda** (valor negociado − custo total, considerando despesas posteriores que diminuem o lucro e entram no caixa do mês de pagamento).
- **Quanto ainda tem a receber** (saldo a receber das vendas em aberto ou parciais).
- **Fluxo de Caixa Mensal**: lucro contábil das vendas do mês, total de entradas recebidas, total de saídas (compras + despesas pagas) e saldo líquido do mês.
- **Exportação para Planilhas (CSV)**: extrato estruturado em UTF-8 (com BOM) e delimitador `;`, compatível com Excel e Google Sheets.
- **Ficha CRLV-e Completa**: normalização de placas (Mercosul e padrão antigo) e preservação estrita de zeros à esquerda em campos numéricos textuais (`renavam` com 11 dígitos e `crvNumber`).

---

## 2. Stack Tecnológica e Arquitetura

| Camada | Tecnologia | Detalhes |
| :--- | :--- | :--- |
| **Interface** | Flutter Web 3.x & Dart | Responsivo, otimizado para toque no Safari (iOS), PWA standalone com manifesto web. |
| **Autenticação** | Firebase Authentication | Login via E-mail/Senha, Google Sign-In, recuperação de senha e tratamento de conflito de provedor. |
| **Banco de Dados** | Cloud Firestore Standard | Transações atômicas para vendas, recebimentos e cancelamentos. Plano Spark (gratuito). |
| **Segurança** | Firestore Security Rules | Acesso restrito a UIDs autorizados no workspace compartilhado (`workspaces/{workspaceId}/members/{uid}`). Bloqueio total a contas externas. |
| **Hospedagem** | Firebase Hosting | Publicado por HTTPS em `https://autosaldo.web.app` com rewrites SPA para `index.html`. |

---

## 3. Como Rodar Localmente

### Pré-requisitos
- **Flutter SDK** (3.x ou superior) com canal estável.
- **Node.js** (v18+) e **Firebase CLI** (`npm install -g firebase-tools`).
- **Navegador** (Google Chrome ou Safari).

### Execução em desenvolvimento:
```bash
# 1. Obter dependências do Flutter
flutter pub get

# 2. Rodar a aplicação Web no navegador
flutter run -d chrome
```

---

## 4. Como Autorizar um Usuário no Espaço de Trabalho

O AutoSaldo utiliza controle de acesso corporativo baseado em lista de membros autorizados. A autenticação por si só não concede acesso às informações financeiras.

### Passo a passo para liberar o acesso:
1. Abra o app (seja localmente ou em `https://autosaldo.web.app`) e realize login com seu e-mail/senha ou conta Google.
2. Se sua conta ainda não foi associada, a tela **Acesso Restrito** será exibida com o seu **UID** do Firebase e um botão para copiá-lo.
3. No [Firebase Console](https://console.firebase.google.com/project/autosaldo/firestore/databases/-default-/data):
   - Acesse a coleção `workspaces`.
   - Selecione o documento `default` (crie-o se não existir).
   - Dentro dele, abra a subcoleção `members`.
   - Adicione um documento com o **ID igual ao seu UID**.
   - Adicione os campos:
     - `uid`: `"<SEU_UID>"` (String)
     - `email`: `"seu@email.com"` (String)
     - `role`: `"owner"` ou `"operator"` (String)
     - `createdAt`: Timestamp
4. O app detecta a liberação em tempo real (via Firestore snapshot stream) e entra automaticamente no painel principal, sem necessidade de recarregar a página.

---

## 5. Como Executar os Testes

O projeto conta com testes unitários em Dart para as regras financeiras e testes automatizados de Security Rules executados contra o Firebase Local Emulator Suite.

### 5.1 Testes Unitários de Domínio e Cálculos Financeiros (Dart):
Valida o exemplo exato da especificação (compra, comissão tardia, recebimento parcelado entre meses, estornos, vendas com prejuízo, formatadores de moeda BRL e placas):
```bash
flutter test
```

### 5.2 Testes Automatizados das Firestore Security Rules:
Valida contra o emulador do Firestore que:
- Contas não autenticadas são bloqueadas;
- Contas autenticadas externas ao workspace têm leitura e gravação negadas;
- Membros autorizados leem e gravam normalmente;
- Zeros à esquerda no RENAVAM e CRV sobrevivem à gravação e à leitura;
- Despesas só podem ser gravadas para veículos existentes;
- O `updatedByUid` deve corresponder à sessão autenticada.

```bash
# Inicia o emulador do Firestore e executa o script de regras:
firebase emulators:exec --only firestore "node test/security_rules_test.mjs"
```

---

## 6. Compilação e Publicação no Firebase Hosting

Para compilar a versão de produção e publicar no Firebase Hosting:

```bash
# 1. Análise estática do código
flutter analyze

# 2. Compilar versão Web otimizada
flutter build web

# 3. Publicar no Firebase Hosting
firebase deploy --only hosting
```

A versão publicada fica disponível imediatamente em:  
🌐 **https://autosaldo.web.app**

---

## 7. Experiência no iPhone (Safari / PWA)

Para a melhor experiência no iOS:
1. Acesse `https://autosaldo.web.app` pelo **Safari**.
2. Toque no ícone de **Compartilhar** (quadrado com seta para cima).
3. Selecione **"Adicionar à Tela de Início"**.
4. Toque em **"Adicionar"**.
5. Abra o ícone **AutoSaldo** direto da Tela de Início. O app iniciará em modo tela cheia (*standalone*), com suporte a *safe areas* (entalhe / Dynamic Island) e teclado otimizado para números e valores monetários.
