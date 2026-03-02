class GestaltCore {
    #state;
    #initialState;
    #actions;
    #view;
    #actionParams;
    #initialEffect;
    #effectCallback

    constructor(effectCallback) {
        if(!effectCallback) throw new Error('Effect callback is required to initialize the application');
        this.#initialState = '%initialState%';
        this.#state = structuredClone(this.#initialState);
        this.#actions = '%actions%';
        this.#view = '%view%';
        this.#actionParams = '%actionParams%';
        this.#initialEffect = '%initialEffect%';
        this.#effectCallback = effectCallback;
        this.#effectCallback(this.#initialEffect);
        if (this.#actions == '%actions%') {
            console.warn('No actions defined for this application');
        }
    }

    static runUnitTests(tests) {
        const results = tests.map(({ description, func, params, pass }) => {
            if (params === undefined) {
                throw new Error(`Test "${description}" is missing 'params' field`);
            }
            return {
                description,
                pass: pass(func(params)),
            }
        })
        const numberPassed = results.filter(result => result.pass).length;
        const numberFailed = results.length - numberPassed;

        if (numberFailed > 0) {
            console.log('Failed Tests:');
            results.filter(result => !result.pass).forEach(result => {
                console.log(`- ${result.description}`);
            });
        }

        console.log(`Unit Tests:\npassed: ${numberPassed},\nfailed: ${numberFailed}`);

        if (numberFailed > 0) {
            throw new Error('Some unit tests failed');
        }
    }

    static meta = {
        name: '%name%',
        version: '%version%',
        author: '%authorName%',
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
        this.#state = state;
        this.#effectCallback(effect);
    }

    get view() {
        return this.#view(this.#state);
    }

    get state() {
        console.warn("[DEBUG] Accessing state directly is meant for debugging purposes. Consider using the view instead.");
        return this.#state;
    }

    get actionParams() {
        return this.#actionParams;
    }


}

export default GestaltCore;