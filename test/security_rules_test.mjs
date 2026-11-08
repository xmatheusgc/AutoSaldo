import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const PROJECT_ID = 'autosaldo';

async function runTests() {
  console.log('--- Iniciando Testes Automatizados das Firestore Security Rules ---');

  const rules = readFileSync('firestore.rules', 'utf8');
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: rules,
      host: '127.0.0.1',
      port: 8080,
    },
  });

  // Configuração inicial com admin (ignora regras para semear membros autorizados)
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    // Cria membros autorizados no workspace 'default'
    await setDoc(doc(adminDb, 'workspaces/default/members/uid_vendedor'), {
      uid: 'uid_vendedor',
      role: 'owner',
      email: 'vendedor@autosaldo.com',
    });
    await setDoc(doc(adminDb, 'workspaces/default/members/uid_operador2'), {
      uid: 'uid_operador2',
      role: 'operator',
      email: 'operador2@autosaldo.com',
    });
  });

  const vendedorContext = testEnv.authenticatedContext('uid_vendedor');
  const vendedorDb = vendedorContext.firestore();

  const operadorContext = testEnv.authenticatedContext('uid_operador2');
  const operadorDb = operadorContext.firestore();

  const externoContext = testEnv.authenticatedContext('uid_externo');
  const externoDb = externoContext.firestore();

  const anonContext = testEnv.unauthenticatedContext();
  const anonDb = anonContext.firestore();

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`  [PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`  [FAIL] ${name}:`, err.message || err);
      failed++;
    }
  }

  // 1. Bloqueio para usuário não autenticado
  await test('Usuário não autenticado não pode ler nem escrever no Firestore', async () => {
    await assertFails(getDoc(doc(anonDb, 'workspaces/default/vehicles/v1')));
    await assertFails(setDoc(doc(anonDb, 'workspaces/default/vehicles/v1'), { brand: 'Fiat' }));
  });

  // 2. Bloqueio para conta externa não autorizada no workspace
  await test('Conta externa autenticada (uid_externo) tem leitura e gravação negadas', async () => {
    await assertFails(getDoc(doc(externoDb, 'workspaces/default/vehicles/v1')));
    await assertFails(
      setDoc(doc(externoDb, 'workspaces/default/vehicles/v1'), {
        brand: 'Fiat',
        model: 'Uno',
        plate: 'ABC1234',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 2000000,
        createdByUid: 'uid_externo',
        updatedByUid: 'uid_externo',
      })
    );
  });

  // 3. Proibição de alterar membros do workspace pelo cliente
  await test('Cliente autenticado não pode modificar a lista de membros do workspace', async () => {
    await assertFails(
      setDoc(doc(vendedorDb, 'workspaces/default/members/hacker_uid'), {
        uid: 'hacker_uid',
        role: 'admin',
      })
    );
  });

  // 4. Vendedor autorizado cria um veículo com RENAVAM e CRV com zeros à esquerda
  await test('Vendedor autorizado cria veículo válido preservando zeros à esquerda (00123456789)', async () => {
    await assertSucceeds(
      setDoc(doc(vendedorDb, 'workspaces/default/vehicles/car_01'), {
        brand: 'Volkswagen',
        model: 'Gol',
        plate: 'ABC1234',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 3000000,
        renavam: '00123456789',
        crvNumber: '00987654',
        docStatus: 'up_to_date',
        createdByUid: 'uid_vendedor',
        updatedByUid: 'uid_vendedor',
      })
    );
  });

  // 5. Segundo operador autorizado enxerga os dados do veículo e zeros à esquerda
  await test('Segundo operador autorizado enxerga o veículo cadastrado e zeros à esquerda sobrevivem', async () => {
    const snap = await assertSucceeds(getDoc(doc(operadorDb, 'workspaces/default/vehicles/car_01')));
    if (!snap.exists()) throw new Error('Documento não encontrado');
    const data = snap.data();
    if (data.renavam !== '00123456789') throw new Error(`RENAVAM corrompido: ${data.renavam}`);
    if (data.crvNumber !== '00987654') throw new Error(`CRV corrompido: ${data.crvNumber}`);
  });

  // 6. Impedir despesa sem veículo correspondente existente
  await test('Impede gravação de despesa apontando para veículo inexistente no mesmo espaço', async () => {
    await assertFails(
      setDoc(doc(vendedorDb, 'workspaces/default/expenses/exp_invalida'), {
        vehicleId: 'veiculo_inexistente_999',
        amountCents: 15000,
        date: '2026-10-05',
        category: 'workshop',
        status: 'valid',
        createdByUid: 'uid_vendedor',
        updatedByUid: 'uid_vendedor',
      })
    );
  });

  // 7. Gravação de despesa válida para o veículo existente
  await test('Permite gravação de despesa válida para veículo existente no espaço', async () => {
    await assertSucceeds(
      setDoc(doc(vendedorDb, 'workspaces/default/expenses/exp_01'), {
        vehicleId: 'car_01',
        amountCents: 200000,
        date: '2026-10-05',
        category: 'workshop',
        status: 'valid',
        createdByUid: 'uid_vendedor',
        updatedByUid: 'uid_vendedor',
      })
    );
  });

  // 8. Rejeita alteração se updatedByUid não corresponder à sessão do usuário
  await test('Rejeita atualização se updatedByUid for falsificado', async () => {
    await assertFails(
      updateDoc(doc(operadorDb, 'workspaces/default/vehicles/car_01'), {
        model: 'Gol 1.6',
        updatedByUid: 'outro_uid_falso',
      })
    );
  });

  console.log(`\nResultado das Security Rules: ${passed} passaram, ${failed} falharam.`);

  await testEnv.cleanup();

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Erro fatal nos testes:', err);
  process.exit(1);
});

