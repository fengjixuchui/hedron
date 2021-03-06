{ hedron, grub2, mtools, OVMF, xorriso, stdenv, qemuBoot }:
let
  grub_image = "grub_image.iso";
in
stdenv.mkDerivation {
  name = "hedron-integration-tests";
  inherit (hedron) src;

  nativeBuildInputs = [ grub2 mtools OVMF xorriso qemuBoot ];

  postPatch = ''
    patchShebangs tools/gen_usb.sh
  '';

  buildPhase = ''
    # This takes a while for unknown reasons, so let's do this only once.
    echo "# Testing legacy direct kernel boot."
    qemu-boot ${hedron}/share/hedron/hypervisor.elf32 | tee output.log

    tools/gen_usb.sh ${grub_image} ${hedron}/share/hedron/hypervisor.elf32 tools/grub.cfg.tmpl

    # We boot our disk images with different amounts of RAM to exercise relocation.
    # If this fails, check whether the hypervisor heap actually fits.
    for mem in 768 1024 3192; do
      echo "# Testing legacy disk image boot with $mem MiB of memory."
      qemu-boot ${grub_image} --memory $mem --disk-image | tee -a output.log
      echo "# Testing UEFI disk image boot with $mem MiB of memory."
      qemu-boot ${grub_image} --memory $mem --disk-image --uefi --uefi-firmware-path ${OVMF.fd}/FV | tee -a output.log
    done

    echo "# Testing done."
  '';

  installPhase = ''
    mkdir -p $out/nix-support
    cp output.log $out/
    echo "report testlog $out output.log" > $out/nix-support/hydra-build-products
  '';
}
