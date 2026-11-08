import { initializeApp } from 'firebase/app';
import { getFirestore, doc, setDoc } from 'firebase/firestore';

// Configuração do projeto autosaldo
const firebaseConfig = {
  apiKey: "AIzaSyD8sOTctNGOIfjebTm484eRmyKhaA9Gvls",
  authDomain: "autosaldo.firebaseapp.com",
  projectId: "autosaldo",
  storageBucket: "autosaldo.firebasestorage.app",
  messagingSenderId: "1062280297793",
  appId: "1:1062280297793:web:3555c8403f4f370b6175c0"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

const uid = process.argv[2];
const email = process.argv[3] || '';
const role = process.argv[4] || 'owner';
const workspaceId = process.argv[5] || 'default';

if (!uid) {
  console.log('Uso: node scripts/authorize_member.mjs <UID> [EMAIL] [ROLE] [WORKSPACE_ID]');
  console.log('Exemplo: node scripts/authorize_member.mjs abc123xyz vendedor@exemplo.com owner default');
  process.exit(1);
}

async function authorize() {
  console.log(`Autorizando UID: ${uid} no workspace: ${workspaceId}...`);
  // Cria o workspace se não existir
  await setDoc(doc(db, `workspaces/${workspaceId}`), {
    name: 'AutoSaldo',
    updatedAt: new Date().toISOString(),
  }, { merge: true });

  // Cria a associação do membro
  await setDoc(doc(db, `workspaces/${workspaceId}/members/${uid}`), {
    uid: uid,
    email: email,
    role: role,
    createdAt: new Date().toISOString(),
  });

  console.log(`[SUCESSO] Usuário ${uid} (${email || "sem email"}) autorizado no workspace "${workspaceId}"!`);
  process.exit(0);
}

authorize().catch((err) => {
  console.error('[ERRO] Falha ao autorizar membro:', err);
  process.exit(1);
});

