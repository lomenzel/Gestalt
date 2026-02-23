import process from 'process';
class GestaltCore {
    #state;
    #initialState;
    #actions;
    #view;
    #actionParams;

    constructor({ initialState, actions, view, actionParams }) {
        this.#initialState = structuredClone(initialState);
        this.#state = structuredClone(initialState);
        this.#actions = actions;
        this.#view = view;
        this.#actionParams = actionParams;
    }

    reset() {
        this.#state = structuredClone(this.#initialState);
    }



    runUnitTests(tests) {
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
            process.exit(1);
        }
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
