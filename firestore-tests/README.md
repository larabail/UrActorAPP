# Firestore security rules tests

Unit tests for `../firestore.rules`, run against the Firebase Local Emulator
Suite (no real project or network access required).

## Prerequisites

- Node.js and npm
- Java (required by the Firestore emulator)
- `firebase-tools` available on PATH (`firebase --version`)

## Running

```bash
npm install
npm test
```

`npm test` runs the whole suite (`emulators:exec` starts the Firestore
emulator, runs the mocha tests against it, then shuts the emulator down).

If you already have an emulator running separately on port 8080, you can run
`npx mocha rules.test.js --timeout 20000` directly instead.

If startup fails with "Port 8080 is not open", an emulator from an earlier run
is still holding the port; stop that process and try again.
