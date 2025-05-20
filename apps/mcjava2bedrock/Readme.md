## Usage

```bash
# ------------------------------------------------------------------------------
#  java2bedrock.sh – Minecraft Java to Bedrock Resource Pack Converter
#
#  Original Author: Kas-tle (https://github.com/Kas-tle)
#  Repository: https://github.com/Kas-tle/java2bedrock.sh
#
#  Description:
#    This script converts Minecraft Java Edition resource packs into
#    Bedrock-compatible packs, including texture and model translation.
#
#  License:
#    The original script is distributed under the terms specified in the
#    source repository. Please refer to the upstream project for details.
#
#  Dockerized by: iPromKnight
#  Notes:
#    This version is embedded in a Docker container to simplify usage and
#    dependency management for cross-platform users.
# ------------------------------------------------------------------------------
```

### Docker

To run, simply:

```bash
docker run --rm -it \
  -v ./input:/app/input \
  -v ./output:/app/target \
  ghcr.io/ipromknight/mcjava2bedrock:rolling \
  /app/input/MyResourcePack.zip
```

To run without settings prompts, use flags:
- `-w (true|false)` whether or not to show the warning prompt
- `-m (pack_to_merge.mcpack)` filename of Bedrock Edition resource pack in the same diretory to merge with result of the conversion
- `-a (attachable_material)` material to use for attachables written by the script
- `-b (block_material)` material to use for blocks written by the script
- `-f (https://somesite.com/fallback_pack.zip|null)` URL of a Java Edition resource to use for fallback textures before the default pack
- `-v (default_asset_version)` version of Minecraft Java Edition for which to pull default assets

For example:

```bash
docker run --rm -it \
  -v ./input:/app/input \
  -v ./output:/app/target \
  ghcr.io/ipromknight/mcjava2bedrock:rolling \
  /app/input/MyResourcePack.zip -w "false" -m "MyBedrock.mcpack" -a "entity_alphatest_one_sided" -b "alpha_test" -f "null" -v "1.18.2"
```

### Item Icons

If you prepare 2D sprites for your 3D models, you can provide the converter with mappings for these sprites to be incorporated into item_texture.json and the exported Geyser mappings. To do so, simply include a file called `sprites.json` in the root of your Java resource pack. The format of this file is as follows:
```json
{
    "leather": [
        {
            "custom_model_data": 1,
            "sprite": "textures/path/to/texture_in_bedrock_rp/texture1"
        },
        {
            "custom_model_data": 2,
            "sprite": "textures/path/to/texture_in_bedrock_rp/texture2"
        }
    ],
    "diamond_axe": [
        {
            "damage_predicate": 2,
            "unbreakable": true,
            "sprite": "textures/path/to/texture_in_bedrock_rp/texture3"
        }
    ]
}
```

When utilizing this feature, you should also use the merge feature to combine the converted pack with an existing Bedrock resource pack containing the specified sprite textures. If using the Github Actions based converter, simply provide a direct download URL of said Bedrock resource pack as done for the Java pack.

### Github Actions

You may also run the converter through Github Actions in this repository by creating an issue with the [Pack Conversion](https://github.com/Kas-tle/java2bedrock.sh/issues/new?assignees=&labels=conversion&template=pack-conversion.yml&title=%5BPack%5D%3A+) template. You are only required to enter the link to the Java pack, though the options described above may also be configured. Your pack will then be queued for conversion by Github Actions. After conversion is complete, the Github Actions bot will reply to your issue with a link to download your converted pack and associated mappings file. Included in the bundle is a behavior pack and addon to view the models in single player, as well as a configuration file containing the paths to the models converted from the Java resource pack and their corresponding identifiers in the Bedrock resource pack.

## About

**NOTICE:** Due to [MCPE-152191](https://bugs.mojang.com/browse/MCPE-152191), any blocks that are larger than 1.9 blocks will not load. This is only relavent to those using the preview pack to display converted models in single player.

The script has been updated to handle parent models and 2D items. It will generate multiple sprite sheets for 3D models without repeating the inclusion of any given texture. 2D item textures will be copied over individually. Note that sprites for 3D items must be added manually.

Your script and resource pack zip file must be in the same directory. Ensure that this zip file is properly setup. It should not have a root directory. Your resource pack must also be formatted correctly, to vanilla specifications. By default, this script will download the default assets in order to generate texture atlases in cases in which you have utilized those. If you wish to use different default assets, you may specify this at the beginning. The default pack will then be downloaded after your specified assets, with your specified assets taking precedence. As long as you provide valid JSON, the script should output something you can use.

You may also specify an input bedrock pack to merge with the output assets produced by the converter. This should be in the same directory as the script and your input Java pack. Like the Java pack, ensure that it is compressed with no root folder. When prompted, type the file name of the input file, such as `example_rp.mcpack`. Merging of behavior packs is not currently supported.

The packs generated by this script can currently only be used in Bedrock Edition 1.16.210.59 and above. Please be sure to enable the experimental setting "Holiday Creator Features" on world generation. You'll probably also want to be in creative mode as that will be the only way to give yourself the blocks generated by the script. Here are the commands to obtain one of the items or place them in your head slot:
```
/give @p geysercmd:gmdl_xxxxxxx
/replaceitem entity @p slot.armor.head 0 geysercmd:gmdl_xxxxxxx
``` 
The `xxxxxxx` term corresponds to the short hash assigned to the model. These are written to config.json, which can be found in the target directory, along with packaged and non-packaged versions of the output assets. This will specify the corresponding item and nbt for each input predicate. The short hash is constructed by combining the predicate entry's item, custom model data, damage, and damaged predicates, taking the md5 hash of this string, and keeping only the first 7 characters. As a result, this hash value will remain the same across conversions.
