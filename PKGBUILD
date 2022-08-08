# Maintainer: 5amu <vcasalino@protonmail.com>
pkgname=burpfeeder
pkgver=0.1
pkgrel=1
pkgdesc="Initial enumeration and mapping of WebApp proxed through BurpSuite"
arch=( "any" )
url="https://github.com/w00dyl3g/BurpFeeder"
provides=( "${pkgname}" )
source=("${pkgname}.sh")
noextract=("${pkgname}.sh")
md5sums=("SKIP")

package() {
        install -Dm755 "${pkgname}.sh" "${pkgdir}/usr/bin/${pkgname}"
}
