// fhirviews: capa entre R y fhirpath.js.
//
// Mantiene en JavaScript un almacen de nodos (recursos FHIR o elementos
// devueltos por FHIRPath, con su tipo) para que R los maneje por su indice y
// pueda evaluar una expresion sobre muchos nodos en una sola llamada.
//
// Requiere que antes se carguen fhirpath.min.js y fhirpath.r4.min.js.

var fhirviews = (function () {
  'use strict';

  var modelo = fhirpath_r4_model;
  var nodos = [];      // nodo (ResourceNode o dato JSON) por indice
  var raices = [];     // recurso de origen de cada nodo (para %resource)
  var compiladas = {}; // cache de expresiones compiladas

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

  var opciones = {
    resolveInternalTypes: false,
    userInvocationTable: {
      getResourceKey: { fn: getResourceKey, arity: { 0: [] } },
      getReferenceKey: {
        fn: getReferenceKey,
        arity: { 0: [], 1: ['TypeSpecifier'] }
      }
    }
  };

  function compilar(expresion) {
    var f = compiladas[expresion];
    if (f === undefined) {
      f = fhirpath.compile(expresion, modelo, opciones);
      compiladas[expresion] = f;
    }
    return f;
  }

  // Convierte un valor de FHIRPath en JSON (cadenas, numeros, logicos u
  // objetos), como lo escribiria FHIR.
  function aJSON(valores) {
    return fhirpath.resolveInternalTypes(valores);
  }

  // Variables: {nombre: valor} o {nombre: {tipo: 'date', valor: '...'}} para
  // las constantes que deben compararse como fechas u horas.
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
        agregar(JSON.parse(t));
      });
      return ids;
    },

    // Agrega recursos (texto JSON con un arreglo) y devuelve sus indices.
    cargar: function (json) {
      var recursos = JSON.parse(json);
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

    // Comprueba que una expresion sea valida; lanza un error si no lo es.
    validar: function (expresion) {
      compilar(expresion);
      return true;
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
