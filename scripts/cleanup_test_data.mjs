import fs from 'fs';
import path from 'path';

async function deleteTestData() {
  const configPath = path.join(process.env.USERPROFILE, '.config', 'configstore', 'firebase-tools.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const token = config.tokens?.access_token;
  const projectId = 'autosaldo';

  const expensesToDelete = [
    '1LUZjGMB7xIubhhh3d8j',
    'Bj9qXQrp36XxR9nKpeuz'
  ];

  const vehiclesToDelete = [
    'XN5GG6qkXyfaJXjHRxan',
    'f3hkN8X1NBhQxRxYLaak'
  ];

  console.log('--- Excluindo Despesas ---');
  for (const id of expensesToDelete) {
    const res = await fetch(`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/workspaces/default/expenses/${id}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log(`Despesa ${id}: ${res.status} ${res.statusText}`);
  }

  console.log('--- Excluindo Veículos ---');
  for (const id of vehiclesToDelete) {
    const res = await fetch(`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/workspaces/default/vehicles/${id}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log(`Veículo ${id}: ${res.status} ${res.statusText}`);
  }

  console.log('✅ Exclusão concluída com sucesso!');
}

deleteTestData().catch(console.error);
