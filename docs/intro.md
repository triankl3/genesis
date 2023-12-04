# Getting Started

### Example
To get an example of usage you can view the [demo place on Roblox](https://www.roblox.com/games/15529154687/Genesis-Demo).

### 1. Get the library
- [Wally Package](https://wally.run/package/triankl3/genesis?version=1.0.0)
- [Roblox Model](https://www.roblox.com/library/15536843454/Genesis-Library)
- Or build from source using Rojo

### 2. Prepare assets
All assets need to be imported into a place and wrapped in a `Model` instance with the `PrimaryPart` property set accordingly. The rest is up to your personal preference.

Keep in mind you can apply changes to all properties which can be changed at runtime using the [`PrefabConfig`](/api/Genesis#PrefabConfig).
This means you can have a single asset which can be used for multiple prefabs with varied effects, colors, materials, scaling, etc...

### 3. Prepare a config
:::tip
This is a lengthy process. Use the demo place as a starting point.
:::
Reference the [API](/api/Genesis) to see what each property does and which types it supports. You can also use `--!strict` to get type checking in your IDE.

### 4. Create the map
Use the [`CreateMap`](/api/Genesis#CreateMap) method to create a map.