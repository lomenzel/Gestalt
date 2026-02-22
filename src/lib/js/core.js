class GestaltCore {
    #state;
    #initialState;
    #actions;
    #view;
    #actionParams;

    constructor({ initialState, actions, view, actionParams  }) {
        this.#initialState = structuredClone(initialState);
        this.#state = structuredClone(initialState);
        this.#actions = actions;
        this.#view = view;
        this.#actionParams = actionParams;
    }

    reset() {
        this.#state = structuredClone(this.#initialState);
    }

    dispatch(action, params = {}) {
        const actionFn = this.#actions[action];
        if (!actionFn) {
            throw new Error(`Unknown action: ${action}`);
        }
        if (typeof params !== 'object' || params === null) {
            throw new Error('Params must be an object');
        }

        const expected = new Set(this.#actionParams[action] ?? []);
        const received = new Set(Object.keys(params));

        for (const key of expected) {
            if (!received.has(key)) {
                throw new Error(`Missing parameter: ${key}`);
            }
        }

        for (const key of received) {
            if (!expected.has(key)) {
                throw new Error(`Unexpected parameter: ${key}`);
            }
        }

        const { state, effect } = actionFn({ state: this.#state, params });
        this.#state = structuredClone(state);
        return effect;
    }

    get view() {
        return this.#view(this.#state);
    }

    get state() {
        return this.#state;
    }


}
