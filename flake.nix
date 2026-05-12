{
	description = "Live Brainfuck interpreter for Neovim";

	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
	};
}