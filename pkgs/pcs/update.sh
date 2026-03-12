#!/usr/bin/env -S nix develop .#update -c bash

updateLock() {
  old_version=$1
  nix develop ".#pcs" --unpack

  cd source
  nix develop ".#pcs" --command bash -c "./autogen.sh && ./configure --with-distro=fedora --enable-local-build && cd .."
  cd ..

  cp source/Gemfile pkgs/pcs
  rm -rf source

  pushd pkgs/pcs

  rm Gemfile.lock gemset.nix
  bundler
  bundix

  git add ./
  git commit -m "pcs: $old_version -> $(nix eval --raw ".#pcs.version")"

  popd
}

old_version=$(nix eval --raw ".#pcs.version")
nix-update --flake pcs
git diff --quiet -- pkgs/pcs/default.nix || updateLock "$old_version"
