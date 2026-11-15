// Pruebas de integridad con datos SIMULADOS; no genera fichas de participantes.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import path from 'node:path';
const require=createRequire(import.meta.url);
const [archivo,modulo]=process.argv.slice(2);
if(!archivo||!modulo)throw Error('Uso: node probar-formulario.mjs formulario.html /ruta/node_modules/jsdom');
const {JSDOM,VirtualConsole}=require(path.resolve(modulo));
const errores=[];
const virtualConsole=new VirtualConsole();
virtualConsole.on('jsdomError',e=>errores.push(e.message));
const html=fs.readFileSync(archivo,'utf8');
const dom=new JSDOM(html,{runScripts:'dangerously',url:'https://kit.example.invalid/',virtualConsole});
const w=dom.window;
const evaluar=c=>JSON.parse(w.eval('JSON.stringify('+c+')'));
assert.equal(evaluar('state.schema'),'fhirviews-piloto-r4-v2');
assert.equal(evaluar('current().fields.version'),'0.5.0.9002');
assert.equal(evaluar('current().fields.participant'),'');
assert.equal(evaluar('current().fields.technical'),'pendiente');
assert.equal(evaluar('report().decision_efectiva'),'pendiente');
assert.ok(evaluar('blockers().length')>0);
assert.equal(w.document.querySelectorAll('#tasks article').length,9);
assert.ok(evaluar('report().tareas').every(t=>t.status==='pendiente'));
// Rechaza el protocolo antiguo y otras identidades, aunque el JSON sea valido.
assert.equal(w.eval("(()=>{try{normalize({...initial(),schema:'fhirviews-protocolo-participantes-v1'});return false}catch{return true}})()"),true);
assert.equal(w.eval("(()=>{try{normalize({...initial(),candidato:'otro'});return false}catch{return true}})()"),true);
assert.equal(w.eval("(()=>{try{normalize({...initial(),protocolo:'otro'});return false}catch{return true}})()"),true);
// Ni el aprobado tecnico ni todas las casillas sustituyen los estados humanos.
w.eval("current().fields.technical='aprobado';for(const t of TASKS.r)taskData(t).checks=t.checks.map(()=>true);current().fields.decision='aceptada'");
assert.equal(evaluar('report().decision_efectiva'),'requiere_revision');
// La prueba completa una ficha ficticia en memoria para comprobar las reglas.
w.eval(`{
 const p=current();Object.assign(p.fields,{session:'SIMULACION-NO-ES-UNA-SESION',participant:'SIMULADO',observer:'SIMULADO',date:'2026-11-15',system:'SIMULADO',rVersion:'SIMULADO',technicalEvidence:'SIMULADO',conclusion:'SIMULADO',maintainerConclusion:'SIMULADO',followup:'SIMULADO',decision:'pendiente'});
 p.identity=p.agreed=p.participantReviewed=p.maintainerReviewed=true;
 for(const t of TASKS.r){const x=taskData(t);Object.assign(x,{status:t.required?'sin_ayuda':'no_evaluada',checks:t.checks.map(()=>true),minutes:'1',interventions:'0',evidence:'SIMULADO',notes:t.required?'':'Fuera del alcance SIMULADO'});}
}`);
assert.equal(evaluar('blockers().length'),0);
assert.equal(evaluar('report().decision_efectiva'),'pendiente');
w.eval("current().fields.decision='aceptada'");
assert.equal(evaluar('report().decision_efectiva'),'aceptada');
w.eval("current().fields.version='0.5.0.9000'");
assert.equal(evaluar('report().decision_efectiva'),'requiere_revision');
w.eval('current().fields.version=REF.version;current().fields.commit="0".repeat(40)');
assert.equal(evaluar('report().decision_efectiva'),'requiere_revision');
w.eval('current().fields.commit=REF.commit;current().fields.checksum="0".repeat(64)');
assert.equal(evaluar('report().decision_efectiva'),'requiere_revision');
w.eval('current().fields.checksum=REF.sha256;current().tasks.R05.status="con_ayuda"');
assert.equal(evaluar('report().decision_efectiva'),'requiere_revision');
w.eval('current().tasks.R05.interventions="1";current().autonomy=true');
assert.equal(evaluar('report().decision_efectiva'),'requiere_revision');
w.eval('current().autonomy=false');
assert.equal(evaluar('report().decision_efectiva'),'aceptada');
w.eval(`current().issues=[{id:'INC-001',task:'R05',summary:'SIMULADO',steps:'SIMULADO',expected:'SIMULADO',observed:'SIMULADO',owner:'SIMULADO',severity:'alto',status:'abierta',retest:''}]`);
assert.equal(evaluar('report().decision_efectiva'),'requiere_revision');
w.eval('current().issues[0].status="cerrada";current().issues[0].retest="SIMULADO: repeticion comprobada"');
assert.equal(evaluar('report().decision_efectiva'),'aceptada');
// Cambiar de perfil conserva las observaciones del primero y no aprueba el otro.
w.document.getElementById('profileFhir').click();
assert.equal(evaluar('state.selected'),'fhir');
assert.equal(evaluar('current().fields.participant'),'');
assert.equal(evaluar('report().decision_efectiva'),'pendiente');
assert.ok(evaluar('report().tareas').every(t=>t.status==='pendiente'));
w.document.getElementById('profileR').click();
assert.equal(evaluar('current().fields.participant'),'SIMULADO');
const retomado=evaluar('normalize(JSON.parse(JSON.stringify(state)))');
assert.equal(retomado.selected,'r');
assert.equal(retomado.profiles.r.fields.participant,'SIMULADO');
assert.equal(retomado.profiles.r.tasks.R05.status,'con_ayuda');
assert.equal(retomado.profiles.r.tasks.R05.interventions,'1');
assert.equal(retomado.profiles.fhir.fields.participant,'');
// El contenido introducido se muestra como texto; el CSV neutraliza formulas.
w.eval(`current().fields.conclusion='<img src=x onerror="window.ejecutado=true">';current().fields.participant='=1+1';render()`);
assert.equal(w.document.querySelectorAll('#closingFields img').length,0);
assert.equal(w.ejecutado,undefined);
assert.ok(w.eval('csv()').includes("'=1+1"));
assert.ok(w.eval('notice()').includes('no fue enviado automáticamente'));
assert.ok(!html.match(/\bfetch\s*\(|XMLHttpRequest|sendBeacon|<script[^>]+src=/));
assert.deepEqual(errores,[]);
dom.window.close();
// file:// puede bloquear localStorage: la ficha debe seguir funcionando.
const local=new JSDOM(html,{runScripts:'dangerously',virtualConsole});
assert.match(local.window.document.getElementById('storageStatus').textContent,/no permite guardar/);
assert.equal(local.window.eval('current().fields.decision'),'pendiente');
local.window.close();
assert.deepEqual(errores,[]);
console.log('Formulario R4: identidad, tareas, cierre humano, importacion, perfiles y modo sin almacenamiento aprobados.');
