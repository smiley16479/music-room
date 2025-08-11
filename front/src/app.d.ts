// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		// interface Locals {}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}

	namespace svelteHTML {
		// allow for custom Svelte element properties
		interface IntrinsicElements {
			[elemName: string]: any;
		}
	}
}

export {};
