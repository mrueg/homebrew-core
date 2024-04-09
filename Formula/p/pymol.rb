class Pymol < Formula
  include Language::Python::Virtualenv
  desc "Molecular visualization system"
  homepage "https://pymol.org/"
  url "https://github.com/schrodinger/pymol-open-source/archive/refs/tags/v3.0.0.tar.gz"
  sha256 "45e800a02680cec62dff7a0f92283f4be7978c13a02934a43ac6bb01f67622cf"
  license :cannot_represent
  head "https://github.com/schrodinger/pymol-open-source.git", branch: "master"

  bottle do
    rebuild 2
    sha256 cellar: :any,                 arm64_sonoma:   "1b3edf37eaeb5b3c38e5fdf9f6a72f4eafecb1f4ea0bb7a9208b0a4e41202a1f"
    sha256 cellar: :any,                 arm64_ventura:  "33fb5ec69774436e99803273fe04c69ec04d4af245361b3ef916141e867c0b08"
    sha256 cellar: :any,                 arm64_monterey: "e2c6c18ea8a6643a96692e427d31b33cf21003c30ec74fadc8aa019b20e881d0"
    sha256 cellar: :any,                 sonoma:         "0d8fa8d46524c5c87123860a1fa0641a1ed0390ab6b2230301f055ad95e8a6a7"
    sha256 cellar: :any,                 ventura:        "2172933239097915902897e01cbef8bf505aa80ec88cc9c1a8028c48de982aed"
    sha256 cellar: :any,                 monterey:       "e9580cbfe839e0ed7cc37d13982ac6928684ff8baf426fc9b23bd2a1ec668290"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "7ecb4cb75a88e52dcdbced60b2bd41dddf14bb5c3671e23737b5b20e6ae4a1a2"
  end

  depends_on "cmake" => :build
  depends_on "glm" => :build
  depends_on "msgpack-cxx" => :build
  depends_on "sip" => :build
  depends_on "freetype"
  depends_on "glew"
  depends_on "libpng"
  depends_on "netcdf"
  depends_on "numpy"
  depends_on "pyqt@5"
  depends_on "python-setuptools" # for pymol/plugins/installation.py
  depends_on "python@3.12"
  uses_from_macos "libxml2"

  on_linux do
    depends_on "freeglut"
  end

  resource "mmtf-cpp" do
    url "https://github.com/rcsb/mmtf-cpp/archive/refs/tags/v1.1.0.tar.gz"
    sha256 "021173bdc1814b1d0541c4426277d39df2b629af53151999b137e015418f76c0"
  end

  resource "msgpack" do
    url "https://files.pythonhosted.org/packages/08/4c/17adf86a8fbb02c144c7569dc4919483c01a2ac270307e2d59e1ce394087/msgpack-1.0.8.tar.gz"
    sha256 "95c02b0e27e706e48d0e5426d1710ca78e0f0628d6e89d5b5a5b91a5f12274f3"
  end

  resource "mmtf-python" do
    url "https://files.pythonhosted.org/packages/d8/0f/f3c132dc9aac9a3f32a0eba7a80f07d14e7624e96f9245eeac5fe48f42cd/mmtf-python-1.1.3.tar.gz"
    sha256 "12a02fe1b7131f0a2b8ce45b46f1e0cdd28b9818fe4499554c26884987ea0c32"
  end

  resource "pmw" do
    url "https://github.com/schrodinger/pmw-patched/archive/8bedfc8747e7757c1048bc5e11899d1163717a43.tar.gz"
    sha256 "3a59e6d33857733d0a8ff0c968140b8728f8e27aaa51306160ae6ab13cea26d3"
  end

  def python3
    which("python3.12")
  end

  def install
    site_packages = Language::Python.site_packages(python3)
    ENV.prepend_path "PYTHONPATH", Formula["numpy"].opt_prefix/site_packages

    resource("mmtf-cpp").stage do
      system "cmake", "-S", ".", "-B", "build", *std_cmake_args(install_prefix: buildpath/"mmtf")
      system "cmake", "--build", "build"
      system "cmake", "--install", "build"
    end

    # install other resources
    resources.each do |r|
      next if r.name == "mmtf-cpp"

      r.stage do
        system python3, *Language::Python.setup_install_args(libexec, python3)
      end
    end

    if OS.linux?
      # Fixes "libxml/xmlwriter.h not found" on Linux
      ENV.append "LDFLAGS", "-L#{Formula["libxml2"].opt_lib}"
      ENV.append "CPPFLAGS", "-I#{Formula["libxml2"].opt_include}/libxml2"
    end
    # CPPFLAGS freetype2 required.
    ENV.append "CPPFLAGS", "-I#{Formula["freetype"].opt_include}/freetype2"
    # Point to vendored mmtf headers.
    ENV.append "CPPFLAGS", "-I#{buildpath}/mmtf/include"

    args = %W[
      --install-scripts=#{libexec}/bin
      --install-lib=#{libexec/site_packages}
      --glut
      --use-msgpackc=c++11
    ]

    system python3, "setup.py", "install", *args
    (prefix/site_packages/"homebrew-pymol.pth").write libexec/site_packages
    bin.install libexec/"bin/pymol"
  end

  def caveats
    "To generate movies, run `brew install ffmpeg`."
  end

  test do
    (testpath/"test.py").write <<~EOS
      from pymol import cmd
      cmd.fragment('ala')
      cmd.zoom()
      cmd.png("test.png", 200, 200)
    EOS
    system "#{bin}/pymol", "-cq", testpath/"test.py"
    assert_predicate testpath/"test.png", :exist?, "Amino acid image should exist"
    system python3, "-c", "import pymol"
  end
end
