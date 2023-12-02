local ASSET_IDS = {
    dotsTexture = "rbxassetid://13243293758",
    vineTexture = "rbxassetid://13256809866",
    mushroomSound = "rbxassetid://10863307715",
}
local COLORS = {
    primary = Color3.fromRGB(50, 77, 85),
    alternative = Color3.fromRGB(98, 206, 254),
    noise = Color3.fromRGB(229, 253, 248),
    object = Color3.fromRGB(101, 198, 33),
    objectDarker = Color3.fromRGB(67, 131, 21),
    light1 = Color3.fromRGB(105, 153, 255),
    light2 = Color3.fromRGB(183, 128, 255)
}

return {
    material = {
        primaryMaterial = Enum.Material.Rock,
        alternativeMaterial = Enum.Material.Slate,
        noiseMaterial = Enum.Material.Ice,
        objectMaterial = Enum.Material.Grass,

        primaryMaterialColor = Color3.fromRGB(50, 77, 85),
        alternativeMaterialColor = Color3.fromRGB(98, 206, 254),
        noiseMaterialColor = Color3.fromRGB(229, 253, 248),
        objectMaterialColor = Color3.fromRGB(101, 198, 33),
    },
    prefabs = {
        Rock1Primary = {
            asset = "Rock1",
            rbxProperties = {
                Bottom = {
                    Color = COLORS["primary"]
                },
                Top = {
                    Color = COLORS["alternative"]
                }
            },
            scale = NumberRange.new(0.75, 2),
            randomRotation = true,
            useNormal = true,
            bury = 0.4,
        },
        Rock2Primary = {
            clone = "Rock1Primary",
            asset = "Rock2"
        },
        Rock3Primary = {
            clone = "Rock1Primary",
            asset = "Rock3"
        },
        Rock4Primary = {
            clone = "Rock1Primary",
            asset = "Rock4"
        },
        Rock5Primary = {
            clone = "Rock1Primary",
            asset = "Rock5"
        },

        Rock1Secondary = {
            clone = "Rock1Primary",
            rbxProperties = {
                Bottom = {
                    Color = COLORS["alternative"]
                },
                Top = {
                    Color = COLORS["primary"]
                }
            }
        },
        Rock2Secondary = {
            clone = "Rock1Secondary",
            asset = "Rock2"
        },
        Rock3Secondary = {
            clone = "Rock1Secondary",
            asset = "Rock3",
        },
        Rock4Secondary = {
            clone = "Rock1Secondary",
            asset = "Rock4"
        },
        Rock5Secondary = {
            clone = "Rock1Secondary",
            asset = "Rock5"
        },

        Rock1Plant = {
            clone = "Rock1Primary",
            rbxProperties = {
                Bottom = {
                    Color = COLORS["primary"]
                },
                Top = {
                    Color = COLORS["object"]
                }
            }
        },
        Rock2Plant = {
            clone = "Rock1Plant",
            asset = "Rock2"
        },
        Rock3Plant = {
            clone = "Rock1Plant",
            asset = "Rock3",
        },
        Rock4Plant = {
            clone = "Rock1Plant",
            asset = "Rock4"
        },
        Rock5Plant = {
            clone = "Rock1Plant",
            asset = "Rock5"
        },

        Flowers1 = {
            asset = "Flowers1",
            rbxProperties = {
                Flowers = {
                    Color = COLORS["objectDarker"]
                }
            },
            scale = NumberRange.new(0.5, 1.5),
            randomRotation = true,
            useNormal = true,
            bury = 0.2
        },
        Bush1 = {
            asset = "Bush1",
            rbxProperties = {
                Leaves = {
                    Color = COLORS["objectDarker"]
                },
                Flowers = {
                    Color = COLORS["light2"],
                    Material = Enum.Material.Neon
                }
            },
            scale = NumberRange.new(1, 1),
            randomRotation = true,
            useNormal = true,
            sound = {
                Volume = 1,
                PlaybackSpeed = 1.5,
                RollOffMinDistance = 10,
                RollOffMaxDistance = 40,
                SoundId = ASSET_IDS["mushroomSound"]
            },
            light = {
                Color = COLORS["light2"],
                Range = 12
            }
        },
        Bush2 = {
            clone = "Bush1",
            rbxProperties = {
                Leaves = {
                    Color = COLORS["objectDarker"]
                },
                Flowers = {
                    Color = COLORS["light1"],
                    Material = Enum.Material.Neon
                }
            },
            scale = NumberRange.new(1, 1),
            randomRotation = true,
            useNormal = true,
            sound = {
                Volume = 1,
                PlaybackSpeed = 2,
                RollOffMinDistance = 10,
                RollOffMaxDistance = 40,
                SoundId = ASSET_IDS["mushroomSound"]
            },
            light = {
                Color = COLORS["light1"],
                Range = 12
            }
        },

        Weird2 = {
            asset = "Weird2",
            rbxProperties = {
                Weird = {
                    Color = COLORS["objectDarker"]
                }
            },
            scale = NumberRange.new(0.5, 1.5),
            randomRotation = true,
            useNormal = true,
            bury = 0.35
        },
        Weird3 = {
            clone = "Weird2",
            asset = "Weird3"
        },

        Mushroom1 = {
            asset = "Mushroom1",
            rbxProperties = {
                Cap = {
                    Color = COLORS["light1"],
                    Material = Enum.Material.Neon
                },
                Stem = {
                    Color = COLORS["objectDarker"]
                },
                Trunk = {
                    Color = COLORS["object"]
                }
            },
            scale = NumberRange.new(0.5, 1.5),
            randomRotation = true,
            useNormal = false,
            bury = 0.1,
            sound = {
                Volume = 3,
                PlaybackSpeed = 0.5,
                RollOffMinDistance = 20,
                RollOffMaxDistance = 60,
                SoundId = ASSET_IDS["mushroomSound"]
            },
            light = {
                Brightness = 2,
                Color = COLORS["light1"],
                Range = 24
            }
        },

        Crystal1 = {
            asset = "Crystal1",
            rbxProperties = {
                Crystal = {
                    Color = COLORS["light2"],
                    Material = Enum.Material.Glass,
                    Transparency = 0.5
                }
            },
            scale = NumberRange.new(0.5, 1.5),
            randomRotation = true,
            useNormal = true,
            bury = 0.25,
            light = {
                Brightness = 2,
                Color = COLORS["light1"],
                Range = 16
            }
        },
        Crystal2 = {
            clone = "Crystal1",
            asset = "Crystal2",
            rbxProperties = {
                Crystal = {
                    Color = COLORS["light1"],
                    Material = Enum.Material.Glass,
                    Transparency = 0.5
                }
            }
        },

        Biolumen = {
            asset = "Plane1",
            scale = NumberRange.new(0.5, 1.5),
            randomRotation = true,
            useNormal = true,
            decal = {
                faces = {Enum.NormalId.Top},
                Color3 = COLORS["light1"],
                Texture = ASSET_IDS["dotsTexture"]
            },
            light = {
                Brightness = 2,
                Range = 12,
                Color = COLORS["light1"]
            }
        },

        Vine = {
            asset = "Plane2",
            randomRotation = true,
            useNormal = false,
            texture = {
                otherChildren = {"2"},
                faces = {Enum.NormalId.Front, Enum.NormalId.Back},
                OffsetStudsU = 3,
                StudsPerTileU = 6,
                StudsPerTileV = 6,
                Texture = ASSET_IDS["vineTexture"],
                Color3 = COLORS["objectDarker"],
            },
            stretch = NumberRange.new(4, 16),
            bury = 0.9 -- SOMETHING IS IFFY HERE, BUT THIS WORKS AS A TEMPORARY SOLUTION
        }
    },
    objects = {
        primaryMaterial = {
            ceiling = {
                Biolumen = 100
            },
            wall = {
                Crystal1 = 10,
                Crystal2 = 10,
                Biolumen = 80
            },
            floor = {
                Rock1Primary = 10,
                Rock2Primary = 10,
                Rock3Primary = 10,
                Rock4Primary = 10,
                Rock5Primary = 10,
                Crystal1 = 25,
                Crystal2 = 25
            }
        },
        alternativeMaterial = {
            ceiling = {
                Biolumen = 100
            },
            wall = {
                Crystal1 = 10,
                Crystal2 = 10,
                Biolumen = 80
            },
            floor = {
                Rock1Secondary = 10,
                Rock2Secondary = 10,
                Rock3Secondary = 10,
                Rock4Secondary = 10,
                Rock5Secondary = 10,
                Crystal1 = 25,
                Crystal2 = 25
            }
        },
        objectMaterial = {
            ceiling = {
                Vine = 100
            },
            wall = {
                Rock1Plant = 1,
                Rock2Plant = 1,
                Rock3Plant = 1,
                Rock4Plant = 1,
                Rock5Plant = 1,
                Weird2 = 45,
                Weird3 = 50
            },
            floor = {
                Mushroom1 = 40,
                Flowers1 = 50,
                Bush1 = 5,
                Bush2 = 5
            }
        }
    }
}