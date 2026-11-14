// fhirviews: capa entre R y fhirpath.js.
//
// Mantiene en JavaScript un almacen de nodos (recursos FHIR o elementos
// devueltos por FHIRPath, con su tipo) para que R los maneje por su indice y
// pueda evaluar una expresion sobre muchos nodos en una sola llamada.
//
// Requiere fhirpath.min.js, fhirpath.r4.min.js y lossless-json.js.

var fhirviews = (function () {
  'use strict';

  var modelo = fhirpath_r4_model;
  var nodos = [];      // nodo (ResourceNode o dato JSON) por indice
  var raices = [];     // recurso de origen de cada nodo (para %resource)
  var compiladas = Object.create(null); // cache de expresiones compiladas

  // --- Funciones de SQL on FHIR que fhirpath.js no trae --------------------

  function getResourceKey(entrada) {
    var salida = [];
    entrada.forEach(function (r) {
      if (r && typeof r === 'object' && r.id !== undefined) {
        salida.push(r.id);
      }
    });
    return salida;
  }

  // Devuelve el id de una referencia relativa o absoluta. Con un tipo,
  // solo devuelve la clave si la referencia apunta a ese tipo de recurso.
  function getReferenceKey(entrada, tipo) {
    var nombre = tipo && tipo.name ? tipo.name : null;
    var salida = [];
    entrada.forEach(function (ref) {
      if (!ref || typeof ref.reference !== 'string') {
        return;
      }
      var partes = ref.reference.split('/_history')[0].split('/');
      if (partes.length < 2) {
        return;
      }
      var id = partes[partes.length - 1];
      var recurso = partes[partes.length - 2];
      if (nombre === null || nombre === recurso) {
        salida.push(id);
      }
    });
    return salida;
  }

  // context.source no existe en todos los V8 distribuidos con R. La copia
  // local de lossless-json permite el mismo resultado en esas plataformas.
  var reviverConFuente = false;
  JSON.parse('1.0', function (k, v, c) {
    if (c && c.source === '1.0') reviverConFuente = true;
    return v;
  });

  function numeroPreciso(texto) {
    return /[.eE]/.test(texto) ?
      fhirpath.FP_Decimal.getDecimal(texto) : Number(texto);
  }

  function leerJSONPreciso(texto) {
    if (reviverConFuente) {
      return JSON.parse(texto, function (k, v, c) {
        return typeof v === 'number' ? numeroPreciso(c.source) : v;
      });
    }
    return LosslessJSON.parse(texto, null, {parseNumber: numeroPreciso});
  }

  // Delega el calculo y la precision a fhirpath.js. Solo completa la zona
  // desconocida de DateTime; Date y Time conservan su tipo y las zonas
  // explicitas permanecen intactas. No se modifica la biblioteca incluida.
  function limiteSoF(entrada, precision, alto) {
    if (precision instanceof fhirpath.FP_Decimal) precision = precision.toNumber();
    if (entrada.length === 0) return [];
    if (entrada.length !== 1) throw new Error('Se esperaba un solo valor');
    var v = fhirpath.util.valDataConverted(entrada[0]);
    if (v == null) return [];
    if (typeof v === 'number' || typeof v === 'bigint') {
      v = fhirpath.FP_Decimal.getDecimal(v);
    }
    if (v instanceof fhirpath.FP_Decimal) {
      var exponente = /^-?\d+(?:\.(\d+))?[eE]([+-]?\d+)$/.exec(v.toString());
      if (exponente) {
        // La escala de 1.0e-2 es 3, y la de 1e2 es -2. La version
        // incluida normaliza esos dos casos antes de calcular el limite.
        // Ajustar una copia conserva intacto el valor del recurso.
        v = fhirpath.FP_Decimal.getDecimal(v);
        v.decimalPlaces = (exponente[1] || '').length - Number(exponente[2]);
      }
    }
    var fn = alto ? 'highBoundary' : 'lowBoundary';
    if (typeof v[fn] !== 'function') throw new Error('Tipo no admitido');
    var resultado = v[fn](precision);
    if (resultado && fhirpath.types([v])[0] === 'System.DateTime') {
      var texto = resultado.toString();
      if (texto.indexOf('T') >= 0 && !/(Z|[+-]\d{2}:\d{2})$/.test(texto)) {
        resultado = fhirpath.evaluate({},
          '@' + texto + (alto ? '-12:00' : '+14:00'), null, modelo,
          {resolveInternalTypes: false})[0];
      }
    }
    return resultado === null ? [] : resultado;
  }

  var opciones = {
    resolveInternalTypes: false,
    userInvocationTable: {
      lowBoundary: {
        fn: function (xs, p) { return limiteSoF(xs, p, false); },
        arity: {0: [], 1: ['Integer']}, internalStructures: true
      },
      highBoundary: {
        fn: function (xs, p) { return limiteSoF(xs, p, true); },
        arity: {0: [], 1: ['Integer']}, internalStructures: true
      },
      getResourceKey: { fn: getResourceKey, arity: { 0: [] } },
      getReferenceKey: {
        fn: getReferenceKey,
        arity: { 0: [], 1: ['TypeSpecifier'] }
      }
    }
  };

  // Una sesion larga puede compilar miles de expresiones distintas (por
  // ejemplo, probandolas con vista_fhirpath()): al pasar del maximo se vacia
  // la cache, que se vuelve a llenar con las que se sigan usando.
  var maxCompiladas = 1000;
  var nCompiladas = 0;

  function compilar(expresion) {
    var f = compiladas[expresion];
    if (f === undefined) {
      f = fhirpath.compile(expresion, modelo, opciones);
      if (nCompiladas >= maxCompiladas) {
        compiladas = Object.create(null);
        nCompiladas = 0;
      }
      compiladas[expresion] = f;
      nCompiladas++;
    }
    return f;
  }

  // Convierte un valor de FHIRPath en JSON (cadenas, numeros, logicos u
  // objetos), como lo escribiria FHIR.
  function aJSON(valores) {
    return fhirpath.resolveInternalTypes(valores);
  }

  // --- Inferencia estatica de tipos ----------------------------------------
  //
  // Para expresiones de navegacion simples (name.where(...).family,
  // value.ofType(Quantity).value, exists(), join(), ...) deduce el tipo FHIR
  // del resultado con el modelo R4 (path2Type), sin datos. Devuelve null si
  // la expresion es mas compleja (operadores, funciones desconocidas).

  var tiposSistema = {
    'System.String': 'string', 'System.Boolean': 'boolean',
    'System.Integer': 'integer', 'System.Decimal': 'decimal',
    'System.Date': 'date', 'System.DateTime': 'dateTime',
    'System.Time': 'time'
  };
  var mismoTipo = ['first', 'last', 'single', 'distinct', 'tail', 'where',
                   'take', 'skip', 'trace', 'intersect', 'exclude'];
  var booleanas = ['exists', 'empty', 'not', 'hasValue', 'all', 'allTrue',
                   'anyTrue', 'allFalse', 'anyFalse', 'isDistinct',
                   'subsetOf', 'supersetOf', 'contains', 'startsWith',
                   'endsWith', 'matches', 'is', 'memberOf', 'htmlChecks',
                   'conformsTo'];
  var enteras = ['count', 'length', 'indexOf'];
  var textos = ['join', 'toString', 'getResourceKey', 'getReferenceKey',
                'substring', 'upper', 'lower', 'replace', 'replaceMatches',
                'trim', 'encode', 'decode', 'escape', 'unescape'];

  function normalizarTipo(t) {
    if (!t) {
      return null;
    }
    t = tiposSistema[t] || t;
    return t.replace(/^(FHIR|System)\./, '');
  }

  // Divide en pasos por los puntos que no estan entre parentesis o comillas
  function partirExpresion(e) {
    var partes = [];
    var actual = '';
    var nivel = 0;
    var comilla = null;
    for (var i = 0; i < e.length; i++) {
      var c = e[i];
      if (comilla) {
        actual += c;
        if (c === comilla && e[i - 1] !== '\\') {
          comilla = null;
        }
        continue;
      }
      if (c === "'" || c === '`') {
        comilla = c;
      } else if (c === '(') {
        nivel++;
      } else if (c === ')') {
        nivel--;
      } else if (c === '.' && nivel === 0) {
        partes.push(actual.trim());
        actual = '';
        continue;
      }
      actual += c;
    }
    partes.push(actual.trim());
    return partes;
  }

  function hijo(ctx, nombre) {
    var claves = [ctx.ruta + '.' + nombre];
    var t = ctx.tipo;
    for (var n = 0; t && n < 20; n++) {
      claves.push(t + '.' + nombre);
      t = modelo.type2Parent[t];
    }
    for (var i = 0; i < claves.length; i++) {
      var tt = normalizarTipo(modelo.path2Type[claves[i]]);
      if (tt) {
        if (tt === 'BackboneElement' || tt === 'Element') {
          return { tipo: tt, ruta: claves[i] };
        }
        return { tipo: tt, ruta: tt };
      }
      if (modelo.choiceTypePaths[claves[i]]) {
        return { tipo: '(eleccion)', ruta: claves[i] };
      }
      // Elementos recursivos (QuestionnaireResponse.item.item, ...)
      var otra = modelo.pathsDefinedElsewhere[claves[i]];
      if (otra) {
        return { tipo: 'BackboneElement', ruta: otra };
      }
    }
    return null;
  }

  function tipoExpresion(ctx, expresion) {
    if (/^\s*%rowIndex\s*$/.test(expresion)) {
      return { tipo: 'integer', ruta: 'integer' };
    }
    var partes = partirExpresion(expresion);
    for (var i = 0; i < partes.length; i++) {
      var p = partes[i];
      if (p === '$this' || (i === 0 && p === ctx.tipo)) {
        continue;
      }
      var m = /^([A-Za-z_][A-Za-z0-9_]*)(\(([\s\S]*)\))?$/.exec(p);
      if (!m) {
        return null;
      }
      var nombre = m[1];
      if (m[2] === undefined) {
        if (ctx.tipo === '(eleccion)') {
          return null;
        }
        ctx = hijo(ctx, nombre);
        if (!ctx) {
          return null;
        }
      } else if (nombre === 'ofType') {
        var t = normalizarTipo(m[3].trim());
        ctx = { tipo: t, ruta: t };
      } else if (nombre === 'extension') {
        ctx = { tipo: 'Extension', ruta: 'Extension' };
      } else if (mismoTipo.indexOf(nombre) >= 0) {
        continue;
      } else if (booleanas.indexOf(nombre) >= 0) {
        ctx = { tipo: 'boolean', ruta: 'boolean' };
      } else if (enteras.indexOf(nombre) >= 0) {
        ctx = { tipo: 'integer', ruta: 'integer' };
      } else if (textos.indexOf(nombre) >= 0) {
        ctx = { tipo: 'string', ruta: 'string' };
      } else {
        return null;
      }
    }
    return ctx.tipo === '(eleccion)' ? null : ctx;
  }

  // Primer elemento de la ruta que no existe en el modelo R4, recorriendo
  // los pasos de navegacion simples como tipoExpresion(). Devuelve
  // {campo, tipo} o null si todos existen o si no se puede saber (elementos
  // de eleccion, variables, operadores o funciones que cambian el tipo).
  function campoDesconocido(ctx, expresion) {
    var partes = partirExpresion(expresion);
    for (var i = 0; i < partes.length; i++) {
      var p = partes[i];
      if (p === '$this' || (i === 0 && p === ctx.tipo)) {
        continue;
      }
      var m = /^([A-Za-z_][A-Za-z0-9_]*)(\(([\s\S]*)\))?$/.exec(p);
      if (!m) {
        return null;
      }
      var nombre = m[1];
      if (m[2] === undefined) {
        if (ctx.tipo === '(eleccion)' ||
            (i === 0 && (nombre === 'true' || nombre === 'false'))) {
          return null;
        }
        var siguiente = hijo(ctx, nombre);
        if (!siguiente) {
          return tipoConocido(ctx.tipo) ? {campo: nombre, tipo: ctx.ruta} : null;
        }
        ctx = siguiente;
      } else {
        // Las funciones se resuelven como en tipoExpresion()
        ctx = tipoExpresion(ctx, p);
        if (!ctx) {
          return null;
        }
      }
    }
    return null;
  }

  // Tipo complejo del modelo (con hijos conocidos)
  function tipoConocido(t) {
    return !!t && t !== '(eleccion)' && /^[A-Z]/.test(t) &&
      (modelo.type2Parent[t] !== undefined || t === 'Element' ||
       t === 'BackboneElement' || t === 'Resource');
  }

  function esRecurso(t) {
    for (var n = 0; t && n < 20; n++) {
      if (t === 'Resource') {
        return true;
      }
      t = modelo.type2Parent[t];
    }
    return false;
  }

  // Variables: {nombre: valor} o {nombre: {literal: '@2020-01-01'}} para las
  // constantes que deben compararse como fechas u horas.
  function prepararVariables(variables) {
    var salida = {};
    if (!variables) {
      return salida;
    }
    Object.keys(variables).forEach(function (k) {
      var v = variables[k];
      if (v && typeof v === 'object' && v.literal !== undefined) {
        salida[k] = fhirpath.evaluate({}, v.literal, null, modelo,
                                      { resolveInternalTypes: false })[0];
      } else {
        salida[k] = v;
      }
    });
    return salida;
  }

  return {
    version: function () {
      return fhirpath.version;
    },

    // Extrae recursos de JSON/Bundle sin normalizar los numeros. Se usa al
    // escribir NDJSON y al leer el banco oficial, antes de pasar por R.
    recursosJSON: function (textos, campo) {
      var salida = [];
      function agregar(x) {
        if (Array.isArray(x)) x.forEach(agregar);
        else if (x && x.resourceType === 'Bundle') {
          (x.entry || []).forEach(function (e) {
            if (e && e.resource) salida.push(LosslessJSON.stringify(e.resource));
          });
        } else salida.push(LosslessJSON.stringify(x));
      }
      textos.forEach(function (t) {
        var x = LosslessJSON.parse(t);
        agregar(campo === null ? x : x[campo]);
      });
      return salida;
    },

    // Marcadores internos del constructor SQL -> FHIR: se convierten en
    // numeros JSON, manteniendo escala y ceros finales, nunca en cadenas.
    serializarRecursos: function (json) {
      var recursos = JSON.parse(json, function (k, v) {
        if (v && typeof v === 'object' &&
            Object.keys(v).length === 1 &&
            typeof v.__fhirviews_decimal === 'string') {
          return new LosslessJSON.LosslessNumber(v.__fhirviews_decimal);
        }
        return v;
      });
      return recursos.map(function (r) { return LosslessJSON.stringify(r); });
    },

    // Agrega recursos a partir de los textos JSON originales (recursos,
    // Bundles o arreglos de ellos) con las mismas reglas que fhir_recursos():
    // de un Bundle se toman entry[].resource. Devuelve los indices.
    cargarTextos: function (textos) {
      var ids = [];
      function agregarRecurso(r) {
        ids.push(nodos.length);
        nodos.push(r);
        raices.push(r);
      }
      function agregar(x) {
        if (Array.isArray(x)) {
          x.forEach(agregar);
        } else if (x && x.resourceType === 'Bundle') {
          (x.entry || []).forEach(function (e) {
            if (e && e.resource) {
              agregarRecurso(e.resource);
            }
          });
        } else {
          agregarRecurso(x);
        }
      }
      textos.forEach(function (t) {
        agregar(leerJSONPreciso(t));
      });
      return ids;
    },

    // Agrega recursos (texto JSON con un arreglo) y devuelve sus indices.
    cargar: function (json) {
      var recursos = leerJSONPreciso(json);
      var ids = [];
      recursos.forEach(function (r) {
        ids.push(nodos.length);
        nodos.push(r);
        raices.push(r);
      });
      return ids;
    },

    // Evalua una expresion sobre varios nodos.
    //   ids:        indices de los nodos
    //   expresion:  texto FHIRPath
    //   variables:  variables comunes (constantes de la vista)
    //   porNodo:    variables distintas para cada nodo, como {nombre: [valor
    //               por nodo]} (p. ej. rowIndex), o null
    //   modo:       'valores' devuelve los resultados en JSON;
    //               'nodos' los guarda en el almacen y devuelve sus indices
    // Devuelve un arreglo con un arreglo de resultados por nodo.
    evaluar: function (ids, expresion, variables, porNodo, modo) {
      var f = compilar(expresion);
      var comunes = prepararVariables(variables);
      return ids.map(function (id, i) {
        var ctx = Object.assign({}, comunes);
        if (porNodo) {
          Object.keys(porNodo).forEach(function (k) {
            ctx[k] = porNodo[k][i];
          });
        }
        ctx.resource = raices[id];
        ctx.rootResource = raices[id];
        var r = f(nodos[id], ctx);
        if (modo === 'nodos') {
          return r.map(function (x) {
            nodos.push(x);
            raices.push(raices[id]);
            return nodos.length - 1;
          });
        }
        return aJSON(r);
      });
    },

    // Tipo FHIR del resultado de una expresion en un contexto {tipo, ruta}, o
    // null si no se puede deducir.
    tipo: function (ctx, expresion) {
      try {
        return tipoExpresion(ctx, expresion);
      } catch (e) {
        return null;
      }
    },

    // Primer elemento inexistente de una ruta en un contexto {tipo, ruta}
    desconocido: function (ctx, expresion) {
      try {
        return campoDesconocido(ctx, expresion);
      } catch (e) {
        return null;
      }
    },

    // ¿Es un tipo de recurso de FHIR R4?
    esRecurso: function (tipo) {
      return esRecurso(tipo);
    },

    // Comprueba que una expresion sea valida; lanza un error si no lo es.
    validar: function (expresion) {
      compilar(expresion);
      return true;
    },

    // Tabla rapida (fhir_tabla): una columna por elemento de primer nivel, en
    // el orden en que aparecen (resourceType e id primero, sin text). Los
    // valores simples se copian; los arreglos de valores simples se unen con
    // '; ' y el resto se escribe como JSON compacto, recortado a `maximo`
    // caracteres. Devuelve {campos: [...], columnas: [[valor por nodo]]}.
    tabla: function (ids, maximo) {
      var otros = [];
      var vistos = {};
      ids.forEach(function (id) {
        var r = nodos[id];
        if (r && typeof r === 'object') {
          Object.keys(r).forEach(function (k) {
            if (!vistos[k]) {
              vistos[k] = true;
              if (k !== 'resourceType' && k !== 'id' && k !== 'text') {
                otros.push(k);
              }
            }
          });
        }
      });
      var campos = ['resourceType', 'id'].filter(function (k) {
        return vistos[k];
      }).concat(otros);
      function simple(v) {
        return v === null || typeof v !== 'object' || v instanceof fhirpath.FP_Decimal;
      }
      function recortar(texto) {
        var letras = Array.from(texto);
        if (letras.length > maximo) {
          return letras.slice(0, maximo - 3).join('') + '...';
        }
        return texto;
      }
      var columnas = campos.map(function (k) {
        return ids.map(function (id) {
          var r = nodos[id];
          var v = r && typeof r === 'object' ? r[k] : undefined;
          if (v === undefined || v === null) {
            return null;
          }
          if (simple(v)) {
            return v;
          }
          if (Array.isArray(v) && v.every(simple)) {
            return recortar(v.join('; '));
          }
          return recortar(JSON.stringify(v));
        });
      });
      // Cada columna como texto JSON aparte, para que R la simplifique por
      // separado (con su propio tipo)
      return {campos: campos, columnas: columnas.map(function (c) {
        return JSON.stringify(c);
      })};
    },

    // Libera los nodos desde el indice dado (0 vacia el almacen).
    liberar: function (desde) {
      nodos.length = desde;
      raices.length = desde;
      return nodos.length;
    },

    tamano: function () {
      return nodos.length;
    }
  };
})();
