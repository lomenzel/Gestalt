(function () {
  'use strict';

  var viewContainer = document.getElementById('viewContainer');
  var paramModal = document.getElementById('paramModal');
  var modalFieldsEl = document.getElementById('modalFields');
  var modalSubmit = document.getElementById('modalSubmit');
  var modalCancel = document.getElementById('modalCancel');
  var modalTitle = document.getElementById('modalTitle');

  window.invokeAction = function invokeAction(actionName, params) {
    try {
      window.core.dispatch(actionName, params);
    } catch (e) {
      console.error('[Gestalt] Action error (' + actionName + '):', e);
      return;
    }
    renderView();
  };

  /* ── Effects ─────────────────────────────────────────────── */

  function executeEffect(effect) {
    if (!window.core) {
      window.pendingEffects = window.pendingEffects || [];
      window.pendingEffects.push(effect);
      return;
    }
    if (!effect || !effect.id) return;
    var handler = effectFunctions[effect.id];
    if (handler) handler(effect.params);
  }


  var effectFunctions = {
    noop: function () { },

    log: function (params) {
      console.log('%c[App]%c ' + params.message, 'color:#30a46c;font-weight:700', 'color:inherit');
    },

    "store.get": function (params) {
      const res = localStorage.getItem(params.key);
      if (res === null) {
        console.log(`[Gestalt][DEBUG] Key "${params.key}" not found in store.`);
        window.invokeAction(params.callbackActionId, { success: false, value: 'Key not found' });
      } else {
        console.log(`[Gestalt][DEBUG] Retrieved key "${params.key}" from store with value:`, res);
        window.invokeAction(params.callbackActionId, { success: true, value: JSON.parse(res) });
      }
    },

    "store.set": function (params) {
      console.log(`[Gestalt][DEBUG] Setting key "${params.key}" in store with value:`, params.value);
      localStorage.setItem(params.key, JSON.stringify(params.value));
    },

    httpRequest: function (params) {
      var opts =
        params.method.toUpperCase() === 'GET'
          ? undefined
          : {
            method: params.method,
            body: params.body,
            headers: params.headers || {},
          };

      fetch(params.url, opts)
        .then(function (resp) {
          return resp.text().then(function (body) {
            return {
              status: resp.status,
              body: body,
              headers: Object.fromEntries(resp.headers.entries()),
            };
          });
        })
        .then(function (data) {
          window.invokeAction(params.callBackActionId, data);
        })
        .catch(function (e) {
          console.error('[Gestalt] HTTP Error:', e.message);
        });
    },

    random: function (params) {
      var result =
        Math.floor(Math.random() * (params.to - params.from + 1)) + params.from;
      window.invokeAction(params.callbackActionId, { result: result });
    },

    invokeAction: function (params) {
      window.invokeAction(params.actionId, params.params);
    },
  };



  /* ── Annotation helper ───────────────────────────────────── */

  function applyAnnotations(el, annotations) {
    if (!annotations || !annotations.length) return;
    annotations.forEach(function (a) {
      if (typeof a === 'string') {
        el.classList.add(a);
      } else if (a && typeof a === 'object' && a.name) {
        el.classList.add(a.name);
      }
    });
  }

  /* ── Modal ───────────────────────────────────────────────── */

  function closeModal() {
    paramModal.classList.remove('active');
  }

  modalCancel.addEventListener('click', closeModal);

  paramModal.addEventListener('click', function (e) {
    if (e.target === paramModal) closeModal();
  });

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && paramModal.classList.contains('active')) {
      closeModal();
    }
  });

  function openParamModal(actionId, fields) {
    modalTitle.textContent = actionId;
    modalFieldsEl.innerHTML = '';

    fields.forEach(function (f) {
      var fieldDiv = document.createElement('div');
      fieldDiv.className = 'modal-field';

      var label = document.createElement('label');
      label.textContent = f;

      var input = document.createElement('input');
      input.id = 'modal-field-' + f;
      input.placeholder = f;

      // Submit on Enter
      input.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') modalSubmit.click();
      });

      fieldDiv.appendChild(label);
      fieldDiv.appendChild(input);
      modalFieldsEl.appendChild(fieldDiv);
    });

    paramModal.classList.add('active');

    var firstInput = modalFieldsEl.querySelector('input');
    if (firstInput) setTimeout(function () { firstInput.focus(); }, 60);

    modalSubmit.onclick = function () {
      var params = {};
      fields.forEach(function (f) {
        var v = document.getElementById('modal-field-' + f).value;
        try {
          params[f] = JSON.parse(v);
        } catch (_) {
          params[f] = v;
        }
      });
      closeModal();
      try {
        window.invokeAction(actionId, params);
      } catch (e) {
        console.error('[Gestalt] Action invoke error:', e);
      }
    };
  }

  /* ── View rendering ──────────────────────────────────────── */

  function renderView() {
    var ui;
    try {
      ui = window.core.view;
    } catch (e) {
      console.error('[Gestalt] View error:', e);
      ui = { elements: [], actions: [] };
    }

    if (Array.isArray(ui)) ui = ui[0];

    viewContainer.innerHTML = '';

    /* Elements */
    if (ui.elements && ui.elements.length) {
      var elementsCard = document.createElement('div');
      elementsCard.className = 'card';

      ui.elements.forEach(function (el) {
        var div = document.createElement('div');
        div.className = 'view-element';
        div.textContent = el.content;
        applyAnnotations(div, el.annotations);
        elementsCard.appendChild(div);
      });

      viewContainer.appendChild(elementsCard);
    }

    /* Actions */
    if (ui.actions && ui.actions.length) {
      var actionsCard = document.createElement('div');
      actionsCard.className = 'card';

      var label = document.createElement('div');
      label.className = 'card-label';
      label.textContent = 'Actions';
      actionsCard.appendChild(label);

      var grid = document.createElement('div');
      grid.className = 'actions-grid';

      ui.actions.forEach(function (a) {
        var btn = document.createElement('button');
        btn.className = 'action-btn';
        btn.textContent = a.content;
        applyAnnotations(btn, a.annotations);

        btn.addEventListener('click', function () {
          // If the view provided concrete params for this action, use them.
          if (a && a.params !== undefined) {
            try {
              console.log('[Gestalt][DEBUG] Invoking action with params:', a.actionId, a.params);
              window.invokeAction(a.actionId, a.params);
            } catch (e) {
              console.error('[Gestalt] Action invoke error:', e);
            }
            return;
          }

          if (!window.core.actionParams || !window.core.actionParams[a.actionId]) {
            throw new Error(`Action parameter type unknown for action: ${a.actionId}, ${window.core.actionParams[a.actionId]}`);
          }
          var fields = (window.core.actionParams && window.core.actionParams[a.actionId]);

          if (fields.length > 0) {
            openParamModal(a.actionId, fields);
          } else {
            try {
              window.invokeAction(a.actionId, {});
            } catch (e) {
              console.error('[Gestalt] Action invoke error:', e);
            }
          }
        });

        grid.appendChild(btn);
      });

      actionsCard.appendChild(grid);
      viewContainer.appendChild(actionsCard);
    }
  }
  window.core = new window.GestaltCore(executeEffect);
  while (window.pendingEffects && window.pendingEffects.length) {
    var effect = window.pendingEffects.shift();
    executeEffect(effect);
  }
  console.log('[Gestalt][DEBUG]', window.core.actionParams)

  /* ── Boot ─────────────────────────────────────────────────── */
  console.log('[Gestalt] Runtime loaded');
  renderView();
})();
