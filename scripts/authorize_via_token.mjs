import fs from 'fs';
import path from 'path';

async function main() {
  const targetUid = process.argv[2] || 'FayTmubFMlSFPL6DRG46O3orbhp2';
  const role = process.argv[3] || 'owner';
  const projectId = 'autosaldo';

  const configPath = path.join(process.env.USERPROFILE, '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(configPath)) {
    console.error('firebase-tools.json não encontrado');
    process.exit(1);
  }

  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  let token = config.tokens?.access_token;
  if (!token) {
    console.error('Token de acesso não encontrado');
    process.exit(1);
  }

  // Tentar buscar informações do usuário pelo Firebase Auth
  let email = '';
  try {
    const lookupRes = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:lookup`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ localId: [targetUid] }),
      }
    );
    if (lookupRes.ok) {
      const data = await lookupRes.json();
      if (data.users && data.users.length > 0) {
        email = data.users[0].email || '';
        console.log(`Encontrado usuário no Firebase Auth: ${email}`);
      }
    } else {
      console.log('Não foi possível buscar detalhes no Auth via lookup, continuando com UID.');
    }
  } catch (e) {
    console.log('Lookup error:', e.message);
  }

  console.log(`Autorizando UID: ${targetUid} (email: "${email}") com role "${role}" no workspace default...`);

  // 1. Garantir documento do workspace default
  const wsUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/workspaces/default`;
  await fetch(wsUrl, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      fields: {
        name: { stringValue: 'AutoSaldo' },
        updatedAt: { stringValue: new Date().toISOString() },
      },
    }),
  });

  // 2. Criar ou atualizar documento do membro em workspaces/default/members/<UID>
  const memberUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/workspaces/default/members/${targetUid}`;
  const memberRes = await fetch(memberUrl, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      fields: {
        uid: { stringValue: targetUid },
        email: { stringValue: email },
        role: { stringValue: role },
        createdAt: { stringValue: new Date().toISOString() },
      },
    }),
  });

  if (!memberRes.ok) {
    const err = await memberRes.text();
    console.error('Erro ao autorizar membro:', err);
    process.exit(1);
  }

  console.log(`✅ Usuário ${targetUid} (${email || 'sem email'}) autorizado com sucesso no workspace!`);
}

main().catch(console.error);
