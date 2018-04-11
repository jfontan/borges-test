require 'net/http'
require 'open-uri'
require 'tempfile'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'minitar'
require 'zlib'

class Borges
  REG_RELEASE = /^v\d+\.\d+\.\d+$/
  GITHUB_URL = 'https://api.github.com/repos/src-d/borges/releases'
  TAR_NAME = 'borges_:VERSION:_:DISTRO:_amd64.tar.gz'
  DIR_NAME = 'borges_:DISTRO:_amd64'

  def initialize(version, distro = 'linux')
    @version = version
    @distro = distro
    @data = parse_version
    @path = nil
  end

  def parse_version
    if REG_RELEASE.match(@version)
      {
        type: :release,
        tag: @version
      }
    else
      {
        type: :file,
        path: @version
      }
    end
  end

  def path
    @path || download
  end

  def download
    if @data[:type] == :file
      @path = @data[:path]
      return
    end

    log("Getting information from version #{@version}")

    release = get_github_release
    url = find_tarball(release)
    tarball = download_tarball(url)
    borges = decompress_tarball(tarball)

    @path = borges
  end

  private

  def get_github_release
    uri = URI(GITHUB_URL)
    res = Net::HTTP.get_response(uri)

    panic("Error getting release: #{res}") if !res.is_a?(Net::HTTPSuccess)

    releases = JSON.parse(res.body)
    release = false

    releases.each do |r|
      if r['tag_name'] == @data[:tag]
        release = r
        break
      end
    end

    panic("Release not found: #{@version}") if !release

    release
  end

  def find_tarball(release)
    filename = subst(TAR_NAME)
    assets = release['assets']

    url = nil
    assets.each do |a|
      if a['name'] == filename
        url = a['browser_download_url']
        break
      end
    end

    panic("Release tarball not found: #{filename}") if !url

    url
  end

  def download_tarball(url)
    log("Downloading release #{url}")

    tempfile = Tempfile.new('borges-tag')
    network = open(url)

    while (b = network.read(4096))
      tempfile.write(b)
    end

    tempfile.close
    FileUtils.cp(tempfile.path, '/tmp/borges_download')

    tempfile
  end

  def decompress_tarball(tarball)
    tmpdir = Dir.mktmpdir('borges-binaries')
    zreader = Zlib::GzipReader.new(File.open(tarball.path, 'rb'))
    err = Minitar.unpack(zreader, tmpdir)
    path = File.join(tmpdir, subst(DIR_NAME), 'borges')
    pp [err, tmpdir, path]

    path
  end

  def subst(text)
    text.
      gsub(':VERSION:', @version).
      gsub(':DISTRO:', @distro)
  end
end
