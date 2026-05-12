{
	description = "Live Brainfuck interpreter for Neovim";

	inputs = {
	    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
	    nixvim.url = "github:nix-community/nixvim";
	    bfdisplay-rs.url = "github:catboylei/bfdisplay-rs";
	};

	outputs = { self, nixpkgs }:
		let
			systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
			forAllSystems = nixpkgs.lib.genAttrs systems;
		in
	{
		packages = forAllSystems (system:
			let
				pkgs = nixpkgs.legacyPackages.${system};
				inherit (pkgs) lib stdenv fetchFromGitHub rustPlatform nodejs pnpm fetchPnpmDeps pnpmConfigHook;

				ver = "1.2.0";

				src = fetchFromGitHub {
					repo = "bfdisplay-rs";
					owner = "catboylei";
					tag = "${ver}";
					sha256 = "sha256-la8bJYDzo8+IEimIOI9BHFP41gewojgyVj2xpmCvo7Q=";
				};

				rust-bin = rustPlatform.buildRustPackage (finalAttrs: {
					name = "bfdisplay-rs-bin";
					inherit src;
					cargoHash = "sha256-Vwb18UxsCttuxZxYxXrIEeVbJ9QwVdNH9I2ys4GUR/0=";
					installPhase = ''
						mkdir -p $out/bin
						cp target/x86_64-unknown-linux-gnu/release/bfDisplay $out/bin/bfdisplay
					'';
				});

				pnpmDeps = fetchPnpmDeps {
					pname = "bfdisplay-rs";
					version = "${ver}";
					inherit src;
					sourceRoot = "${src.name}/plugin";
					fetcherVersion = 3;
					hash = "sha256-LOHvnIOzCG3V4fi2lWt98/HTzOZ/YPlt7ph/ycLmbpA=";
				};

				bfdisplay-rs = stdenv.mkDerivation {
					pname = "bfdisplay-rs";
					version = "${ver}";

					nativeBuildInputs = [ nodejs pnpm pnpmConfigHook ];
					inherit src pnpmDeps;

					pnpmRoot = "plugin";

					preBuild = ''
						substituteInPlace plugin/src/init.ts \
							--replace-fail "state.script_dir + '/bfDisplay'" "'${rust-bin}/bin/bfdisplay'"
					'';

					buildPhase = ''
						runHook preBuild

						pushd plugin
						pnpm run build
						popd

						runHook postBuild
					'';

					installPhase = ''
						runHook preInstall

						mkdir -p $out/lua
						cp plugin/target/bfDisplay-rs.lua $out/lua/

						runHook postInstall
					'';

					meta = {
						description = "Live Brainfuck interpreter for Neovim";
						license = lib.licenses.agpl3Only;
						homepage = "https://github.com/catboylei/bfDisplay-rs";
					};
				};
			in
			{
				inherit bfdisplay-rs;
				default = bfdisplay-rs;
			}
		);

		overlays.default = final: prev: {
			bfdisplay-rs = self.packages.${final.system}.bfdisplay-rs;
		};

		homeModules = { config, lib, pkgs, ... }:
		let
            cfg = config.programs.nixvim.plugins.bfdisplay-rs;
            package = self.packages.${pkgs.system}.default;
		in
		{
            options.programs.nixvim.plugins.bfdisplay-rs = {
                enable = lib.mkEnableOption "bfdisplay-rs";

                enabled = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Whether the plugin sets up at all";
                };

                autostart = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Whether to autostart when opening a matching file";
                };

                patterns = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ "*.bf" "*.b" "*.brainfuck" ];
                    description = "File extensions to trigger the plugin";
                };

                displayRows = lib.mkOption {
                    type = lib.types.int;
                    default = 1;
                    description = "Amount of rows the live cell display should show";
                };

                cellDisplay = lib.mkOption {
                	type = lib.types.bool;
                	default = true;
                	description = "Whether the cell display should be rendered";
                };

                syntaxHighlight = lib.mkOption {
                	type = lib.types.bool;
                	default = true;
                	description = "Whether syntax highlighting should be rendered";
                };

                operatorColor = lib.mkOption {
                	type = lib.types.nullOr lib.types.str;
                	default = null;
                	description = "Color for +- operators";
                };

            	pointerColor = lib.mkOption {
            		type = lib.types.nullOr lib.types.str;
            		default = null;
            		description = "Color for <> operators";
            	};

            	ioColor = lib.mkOption {
            		type = lib.types.nullOr lib.types.str;
					default = null;
					description = "Color for ., operators";
            	};

            	loopColor = lib.mkOption {
            		type = lib.types.nullOr lib.types.str;
            		default = null;
            		description = "Color for [] operators";
            	};

            	otherColor = lib.mkOption {
            		type = lib.types.nullOr lib.types.str;
            		default = null;
            		description = "Color for every other character";
            	};

                config = lib.mkIf cfg.enable {
                    programs.nixvim.extraPlugins = [ package ];
                    programs.nixvim.extraConfigLua = ''require("bfDisplay-rs").setup()'';

                    home.file.".local/share/nvim/bfDisplay-rs/config.lua".text =
					let
						luaVal = v:
							if v == null then "nil"
							else if builtins.isBool v then (if v then "true" else "false")
							else if builtins.isInt v then toString v
							else if builtins.isList v then
								"{" + lib.concatMapStringsSep ", " (x: "\"${x}\"") v + "}"
							else "\"${v}\"";
					in
					''
						-- This file is managed by Home Manager. Do not edit it manually.
						-- Changes should be made via programs.nixvim.plugins.bfdisplay-rs in your config.

						return {
							ENABLED = ${luaVal cfg.enabled},
							AUTOSTART = ${luaVal cfg.autostart},
							PATTERNS = ${luaVal cfg.patterns},
							DISPLAY_ROWS = ${luaVal cfg.displayRows},
							CELL_DISPLAY = ${luaVal cfg.cellDisplay},
							SYNTAX_HIGHLIGHT = ${luaVal cfg.syntaxHighlight},
							OPERATOR_COLOR = ${luaVal cfg.operatorColor},
							POINTER_COLOR = ${luaVal cfg.pointerColor},
							IO_COLOR = ${luaVal cfg.ioColor},
							LOOP_COLOR = ${luaVal cfg.loopColor},
							OTHER_COLOR = ${luaVal cfg.otherColor},
						}
					'';
                };
            };
		};
	};
}