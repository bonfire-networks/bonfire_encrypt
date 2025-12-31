# Bonfire.Encrypt

Experimenting with encryption for [Bonfire](https://bonfire.cafe/). Not ready for use.



## How to use it

This requires https://openmls.tech wasm bindings, for now clone https://github.com/bonfire-networks/openmls/tree/wasm-bindings to `/assets/static/assets/openmls` and run:

```
cargo install wasm-pack

cargo build --release --verbose --target wasm32-unknown-unknown -p openmls -F js

cd openmls-wasm && ./build.sh
```

## Copyright and License

Copyright (c) 2022 Bonfire Contributors, GNU Affero General Public License

Some of the code is originally based on [Live Secret](https://github.com/JesseStimpson/livesecret): Copyright (c) 2022 Jesse Stimpson, Apache License 2.0

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with this program.  If not, see <https://www.gnu.org/licenses/>.
