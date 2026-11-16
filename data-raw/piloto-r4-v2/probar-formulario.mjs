// Datos SIMULADOS solo en memoria. No crea fichas ni observaciones humanas.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import path from 'node:path';
const require=createRequire(import.meta.url);
const [archivo,modulo]=process.argv.slice(2);
if(!archivo||!modulo)throw Error('Uso: node probar-formulario.mjs formulario.html /ruta/node_modules/jsdom');
const {JSDOM,VirtualConsole}=require(path.resolve(modulo));
const errores=[],virtualConsole=new VirtualConsole();
virtualConsole.on('jsdomError',e=>errores.push(e.message));
const html=fs.readFileSync(archivo,'utf8');
const dom=new JSDOM(html,{runScripts:'dangerously',url:'https://kit.example.invalid/',virtualConsole});
const w=dom.window;
const evaluar=c=>JSON.parse(w.eval('JSON.stringify('+c+')'));
const revision=()=>evaluar('report().decision_efectiva');
const pendientes=()=>evaluar('blockers()');
function simular(perfil='r',alcance='nucleo'){
 w.eval(`{
  state=initial();state.selected=${JSON.stringify(perfil)};
  const p=current();Object.assign(p.fields,{session:'SIMULACION-NO-ES-UNA-SESION',participant:'SIMULADO',observer:'SIMULADO',date:'2026-11-15',system:'SIMULADO',rVersion:'SIMULADO',experience:'SIMULADO',dependencies:'SIMULADO',scope:'SIMULADO',technicalLevel:${JSON.stringify(alcance==='siete'?'completo':'basico')},scopeLevel:${JSON.stringify(alcance)},profileValidation:'no_evaluada',profileEvidence:'SIMULADO: plan, sin servidor',technical:'aprobado',technicalEvidence:'SIMULADO',conclusion:'SIMULADO',maintainerConclusion:'SIMULADO',priorities:'SIMULADO',followup:'SIMULADO',decision:'aceptada'});
  p.identity=p.agreed=p.participantReviewed=p.maintainerReviewed=true;
  for(const t of TASKS[state.selected]){const x=taskData(t);Object.assign(x,{status:required(t)?'sin_ayuda':'no_evaluada',checks:t.checks.map(()=>true),minutes:'1',waiting:'0',interventions:'0',evidence:'SIMULADO',answers:'RESPUESTA SIMULADA, no observada',understanding:'correcta',notes:required(t)?'':'Fuera del alcance SIMULADO'});}
  const repetir=state.selected==='r'?['R05','R06']:['F03','F04','F05'];
  for(const id of repetir)Object.assign(p.tasks[id],{repeatStatus:'sin_ayuda',repeatInterventions:'0',repeatEvidence:'SIMULADO: intento02',repeatNotes:'SIMULADO: repeticion manual'});
  render();
 }`);
 assert.deepEqual(pendientes(),[]);
 assert.equal(revision(),'aceptada');
}
assert.equal(evaluar('state.schema'),'fhirviews-piloto-r4-v2');
assert.equal(evaluar('state.revision_protocolo'),'2.1');
assert.equal(evaluar('current().fields.version'),'0.5.0.9002');
assert.equal(evaluar('current().fields.participant'),'');
assert.equal(revision(),'pendiente');
assert.equal(w.document.querySelectorAll('#tasks article').length,9);
assert.ok(evaluar('report().tareas').every(t=>t.status==='pendiente'));
assert.notDeepEqual(evaluar('TASKS_ES.r.map(t=>t.title)'),evaluar('TASKS_ES.fhir.map(t=>t.title)'));
for(const key of ['r','fhir']){
 const es=evaluar(`TASKS_ES.${key}`),en=evaluar(`TASKS_EN.${key}`);
 assert.equal(es.length,9);assert.equal(en.length,9);
 es.forEach((t,i)=>{assert.equal(t.id,en[i].id);assert.equal(t.required_scope,en[i].required_scope);for(const field of ['steps','checks','questions'])assert.equal(t[field].length,en[i][field].length);});
}
// Identidad, ronda y protocolo son necesarios para retomar un registro.
for(const change of ["schema:'antiguo'","candidato:'otro'","protocolo:'otro'","revision_protocolo:'2.0'"]){
 assert.equal(w.eval(`(()=>{try{normalize({...initial(),${change}});return false}catch{return true}})()`),true);
}
// Las casillas y el resultado automático no completan las tareas humanas.
w.eval("current().fields.technical='aprobado';for(const t of TASKS.r)taskData(t).checks=t.checks.map(()=>true);current().fields.decision='aceptada'");
assert.equal(revision(),'requiere_revision');
simular();
for(const field of ['version','commit','checksum']){
 const original=evaluar(`current().fields.${field}`);w.eval(`current().fields.${field}='otro'`);assert.equal(revision(),'requiere_revision');w.eval(`current().fields.${field}=${JSON.stringify(original)}`);
}
// El laboratorio no puede excluirse en siete ni ejecutarse como básico.
w.eval("current().fields.scopeLevel='siete'");assert.equal(revision(),'requiere_revision');
w.eval("current().fields.technicalLevel='completo'");assert.ok(pendientes().some(x=>x.includes('R09')));
simular('r','siete');assert.equal(evaluar("report().tareas.find(t=>t.id==='R09').obligatoria"),true);
w.eval("current().tasks.R09.status='no_evaluada';current().tasks.R09.notes='SIMULADO'");assert.equal(revision(),'requiere_revision');
simular();assert.equal(evaluar("report().tareas.find(t=>t.id==='R09').obligatoria"),false);
// Ejecutar sin entender no permite cerrar; se conservan respuestas y justificación.
for(const understanding of ['pendiente','parcial','incorrecta']){w.eval(`current().tasks.R05.understanding=${JSON.stringify(understanding)}`);assert.equal(revision(),'requiere_revision');}
w.eval("current().tasks.R05.understanding='correcta';current().tasks.R05.answers=''");assert.equal(revision(),'requiere_revision');
w.eval("current().tasks.R05.answers='SIMULADO'");assert.equal(revision(),'aceptada');
for(const [key,value] of [['minutes','-1'],['waiting','Infinity'],['interventions','0.5']]){
 const original=evaluar(`current().tasks.R05.${key}`);w.eval(`current().tasks.R05.${key}=${JSON.stringify(value)}`);assert.equal(revision(),'requiere_revision');w.eval(`current().tasks.R05.${key}=${JSON.stringify(original)}`);
}
w.eval("current().tasks.R05.status='con_ayuda'");assert.equal(revision(),'requiere_revision');
w.eval("current().tasks.R05.interventions='1';current().tasks.R05.notes='SIMULADO: pista documentada'");assert.equal(revision(),'aceptada');
// Puede haber aprendizaje: primer intento asistido y repetición independiente.
w.eval('current().autonomy=true');assert.equal(revision(),'aceptada');assert.deepEqual(evaluar('report().autonomia_documentada_tareas'),['R05','R06']);
w.eval("current().tasks.R05.repeatInterventions='1'");assert.equal(revision(),'requiere_revision');
w.eval("current().tasks.R05.repeatInterventions='0';current().tasks.R05.repeatEvidence=''");assert.equal(revision(),'requiere_revision');
simular();w.eval("current().tasks.R06.repeatStatus='no_realizada'");assert.equal(revision(),'requiere_revision');
simular();w.eval("current().tasks.R06.repeatStatus='fallo'");assert.equal(revision(),'requiere_revision');
simular();
// Incidencias altas necesitan cierre comprobado; menores, pendientes explícitos.
w.eval("current().issues=[{id:'INC-001',task:'R05',summary:'SIMULADO',steps:'SIMULADO',expected:'SIMULADO',observed:'SIMULADO',evidence:'SIMULADO',owner:'SIMULADO',severity:'alto',status:'abierta',retest:''}]");assert.equal(revision(),'requiere_revision');
w.eval("current().fields.decision='aceptada_pendientes'");assert.equal(revision(),'requiere_revision');
w.eval("current().issues[0].severity='bajo'");assert.equal(revision(),'aceptada_pendientes');
w.eval("current().fields.decision='aceptada'");assert.equal(revision(),'requiere_revision');
w.eval("current().issues[0].status='cerrada'");assert.equal(revision(),'requiere_revision');
w.eval("current().issues[0].retest='SIMULADO: retest comprobado'");assert.equal(revision(),'aceptada');
// El perfil FHIR exige plan explícito, pero ningún servidor para cerrar el núcleo.
simular('fhir');w.eval("current().fields.profileEvidence=''");assert.equal(revision(),'requiere_revision');
w.eval("current().fields.profileEvidence='SIMULADO: plan sin servidor'");assert.equal(revision(),'aceptada');
w.eval("current().fields.profileValidation='indeterminada'");assert.equal(revision(),'requiere_revision');
simular('fhir','siete');
// Idiomas: mismas respuestas, estados y evidencias; rótulos y exportaciones cambian.
w.eval("current().tasks.F05.answers='RESPUESTA EN ESPAÑOL QUE NO SE TRADUCE';current().autonomy=true");
const profilesBefore=evaluar('state.profiles');
w.document.getElementById('language').value='en';w.document.getElementById('language').dispatchEvent(new w.Event('change'));
assert.equal(w.document.documentElement.lang,'en');assert.equal(evaluar('state.language'),'en');
assert.deepEqual(evaluar('state.profiles'),profilesBefore);
assert.match(w.document.getElementById('profileTitle').textContent,/FHIR profile/);
assert.match(w.document.getElementById('task-F02').querySelector('h3').textContent,/Review mappings/);
assert.match(w.document.querySelector('label[for="meta-scopeLevel"]').textContent,/Agreed human-evaluation scope/);
assert.ok(w.document.querySelector('a[href="EVALUACION-PILOTO.en.md"]'));
assert.match(w.eval('textReport()'),/Understanding:/);assert.match(w.eval('textReport()'),/RESPUESTA EN ESPAÑOL QUE NO SE TRADUCE/);
assert.ok(w.eval('csv()').startsWith('\ufeff"record_type"'));assert.match(w.eval('csv()'),/"understanding"/);
assert.match(w.eval('notice()'),/not sent automatically/);assert.equal(revision(),'aceptada');
assert.match(w.document.getElementById('gate').textContent,/Declared decision: Accepted for the stated scope/);
const csvLines=w.eval('csv()').replace(/^\ufeff/,'').split('\r\n');
const splitLine=line=>line.slice(1,-1).split('","');
const csvHeader=splitLine(csvLines[0]),csvRow=splitLine(csvLines.find(line=>line.includes('"F03"')));
const csvValue=name=>csvRow[csvHeader.indexOf(name)];
assert.equal(csvValue('record_type'),'task');
assert.equal(csvValue('level'),'Full · DBI/DuckDB');assert.equal(csvValue('level_code'),'completo');
assert.equal(csvValue('scope'),'Seven constructors · laboratory required');assert.equal(csvValue('scope_code'),'siete');
assert.equal(csvValue('understanding'),'Correct');assert.equal(csvValue('understanding_code'),'correcta');
assert.equal(csvValue('repeat'),'Repeated without assistance');assert.equal(csvValue('repeat_code'),'sin_ayuda');
w.eval("current().fields.technical='no_aprobado'");
assert.match(w.eval('textReport()'),/EFFECTIVE DECISION: Review required/);
w.eval("current().fields.technical='aprobado'");
w.eval('setLanguage("es")');assert.equal(w.document.documentElement.lang,'es');assert.deepEqual(evaluar('state.profiles'),profilesBefore);
assert.match(w.eval('textReport()'),/Comprensión:/);assert.ok(w.eval('csv()').startsWith('\ufeff"tipo"'));
const retomar=evaluar('normalize(JSON.parse(JSON.stringify(state)))');assert.deepEqual(retomar.profiles,profilesBefore);
// La autonomía documentada excluye tareas con evidencia o controles incompletos.
for(const [key,value] of [['repeatNotes',''],['answers',''],['evidence','']]){
 const previous=evaluar(`current().tasks.F03.${key}`);
 w.eval(`current().tasks.F03.${key}=${JSON.stringify(value)}`);
 assert.ok(!evaluar('report().autonomia_documentada_tareas').includes('F03'));
 w.eval(`current().tasks.F03.${key}=${JSON.stringify(previous)}`);
}
w.eval('current().tasks.F03.checks[0]=false');assert.ok(!evaluar('report().autonomia_documentada_tareas').includes('F03'));
w.eval('current().tasks.F03.checks[0]=true');
// Exportar/retomar usa los botones y el importador reales: no recorta textos
// largos ni descarta incidencias después de la número 200.
let exported;
w.download=(name,content,type)=>{exported={name,content,type};};
const longAnswer='ñ'.repeat(2200000);
const answerInput=w.document.getElementById('F05-answers');
answerInput.value=longAnswer;answerInput.dispatchEvent(new w.Event('input'));
w.document.getElementById('exportJson').click();
assert.ok(Buffer.byteLength(exported.content,'utf8')>4000000);
const exportSnapshot=JSON.parse(exported.content);
assert.equal(exportSnapshot.profiles.fhir.tasks.F05.answers,longAnswer);
const manyIssues=structuredClone(exportSnapshot);
manyIssues.profiles.fhir.issues=Array.from({length:201},(_,i)=>({id:'INC-'+(i+1),task:'F05',summary:'SIMULADO '+i}));
assert.equal(w.normalize(manyIssues).profiles.fhir.issues.length,201);
w.eval('state=initial();render()');w.confirm=()=>true;
const importInput=w.document.getElementById('importFile');
Object.defineProperty(importInput,'files',{configurable:true,value:[{size:Buffer.byteLength(exported.content,'utf8'),text:async()=>exported.content}]});
await importInput.onchange({target:importInput});
assert.equal(evaluar('current().tasks.F05.answers'),longAnswer);
assert.equal(w.document.getElementById('F05-answers').value,longAnswer);
assert.deepEqual(evaluar('state.profiles'),exportSnapshot.profiles);
// Cambiar perfil conserva el otro y no inventa participantes.
w.document.getElementById('profileR').click();assert.equal(evaluar('current().fields.participant'),'');assert.equal(revision(),'pendiente');
w.document.getElementById('profileFhir').click();assert.equal(evaluar('current().fields.participant'),'SIMULADO');
// Texto introducido permanece texto y el CSV neutraliza fórmulas.
w.eval(`current().fields.conclusion='<img src=x onerror="window.ejecutado=true">';current().fields.participant='=1+1';render()`);
assert.equal(w.document.querySelectorAll('#closingFields img').length,0);assert.equal(w.ejecutado,undefined);assert.ok(w.eval('csv()').includes("'=1+1"));
assert.ok(!html.match(/\bfetch\s*\(|XMLHttpRequest|sendBeacon|<script[^>]+src=/));
assert.deepEqual(errores,[]);dom.window.close();
// file:// puede impedir almacenamiento: ambas versiones siguen funcionando.
const local=new JSDOM(html,{runScripts:'dangerously',virtualConsole});
assert.match(local.window.document.getElementById('storageStatus').textContent,/no permite guardar/);
local.window.eval('setLanguage("en")');assert.match(local.window.document.getElementById('storageStatus').textContent,/unavailable/);
assert.equal(local.window.eval('current().fields.decision'),'pendiente');local.window.close();assert.deepEqual(errores,[]);
console.log('Formulario ES/EN: identidad, alcance, comprensión, ayuda, repetición, incidencias, exportaciones y continuidad aprobados.');
