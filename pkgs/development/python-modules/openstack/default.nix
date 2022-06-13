{ pkgs, lib, poetry2nix, python3Packages, ... }:

let
  pythonPackages = (poetry2nix.mkPoetryPackages {
    projectDir = ./.;
    overrides = [
      poetry2nix.defaultPoetryOverrides
      (self: super: {
        numpy = python3Packages.numpy;
	tempita = python3Packages.tempita;

	testtools = super.testtools.overridePythonAttrs (old: {
	  propagatedBuildInputs = with super; [ extras ];

	  postPatch = ''
	    sed -i '/fixtures/d' requirements.txt
	  '';
	});

	futurist = super.futurist.overridePythonAttrs (old: {
	  buildInputs = old.buildInputs ++ (with self; [ pbr ]);
	});

	microversion-parse = super.microversion-parse.overridePythonAttrs (old: {
	  buildInputs = old.buildInputs ++ (with self; [ pbr ]);
	});

	oslo-rootwrap = super.oslo-rootwrap.overridePythonAttrs (old: {
	  buildInputs = old.buildInputs ++ (with self; [ pbr ]);
	});

	scrypt = super.scrypt.overridePythonAttrs (old: {
	  buildInputs = old.buildInputs ++ (with self; [ pkgs.openssl.dev ]);
	});

	keystone = super.keystone.overridePythonAttrs (old: {
	  propagatedBuildInputs = old.propagatedBuildInputs ++ (with self; [ psycopg2 ]);
	});
      })
    ];
  }).python.pkgs;

in pythonPackages
