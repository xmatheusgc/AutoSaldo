import fs from 'fs';
import path from 'path';

async function main() {
  const configPath = path.join(process.env.USERPROFILE, '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(configPath)) {
    console.error('firebase-tools.json não encontrado');
    process.exit(1);
  }

  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const token = config.tokens?.access_token;
  if (!token) {
    console.error('Token de acesso não encontrado');
    process.exit(1);
  }

  const targetUid = 'SXhMSch7l7gnGmKViMgkCcCbd5t2';
  const email = 'matheusgc1006@gmail.com';
  const projectId = 'autosaldo';

  console.log(`Autorizando ${email} (${targetUid}) no Firestore...`);

  // 1. Criar ou atualizar documento do workspace default
  const wsUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/workspaces/default`;
  const wsRes = await fetch(wsUrl, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      fields: {
        name: { stringValue: 'AutoSaldo' },
        updatedAt: { stringValue: new Date().toISOString() },
      },
    }),
  });

  if (!wsRes.ok) {
    const err = await wsRes.text();
    console.error('Erro ao atualizar workspace:', err);
    process.exit(1);
  }

  // 2. Criar documento do membro em workspaces/default/members/<UID>
  const memberUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/workspaces/default/members/${targetUid}`;
  const memberRes = await fetch(memberUrl, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      fields: {
        uid: { stringValue: targetUid },
        email: { stringValue: email },
        role: { stringValue: 'owner' },
        createdAt: { stringValue: new Date().toISOString() },
      },
    }),
  });

  if (!memberRes.ok) {
    const err = await memberRes.text();
    console.error('Erro ao autorizar membro:', err);
    process.exit(1);
  }

  console.log('✅ Usuário autorizado com sucesso no Firestore!');
}

main().catch(console.error);

