# frozen_string_literal: true

require 'discourse_plugin_registry'

RSpec.describe DiscoursePluginRegistry do

  class TestRegistry < DiscoursePluginRegistry; end

  let(:registry) { TestRegistry }
  let(:registry_instance) { registry.new }

  context '::define_register' do
    let(:fresh_registry) { Class.new(TestRegistry) }

    let(:plugin_class) do
      Class.new(Plugin::Instance) do
        attr_accessor :enabled
        def enabled?
          @enabled
        end
      end
    end

    let(:plugin) { plugin_class.new }

    it 'works for a set' do
      fresh_registry.define_register(:test_things, Set)
      fresh_registry.test_things << "My Thing"
      expect(fresh_registry.test_things).to contain_exactly("My Thing")
      fresh_registry.reset!
      expect(fresh_registry.test_things.length).to eq(0)
    end

    it 'works for a hash' do
      fresh_registry.define_register(:test_things, Hash)
      fresh_registry.test_things[:test] = "hello world"
      expect(fresh_registry.test_things[:test]).to eq("hello world")
      fresh_registry.reset!
      expect(fresh_registry.test_things[:test]).to eq(nil)
    end

    context '::define_filtered_register' do
      it 'works' do
        fresh_registry.define_filtered_register(:test_things)
        expect(fresh_registry.test_things.length).to eq(0)

        fresh_registry.register_test_thing("mything", plugin)

        plugin.enabled = true
        expect(fresh_registry.test_things).to contain_exactly("mything")

        plugin.enabled = false
        expect(fresh_registry.test_things.length).to eq(0)
      end
    end
  end

  describe '#stylesheets' do
    it 'defaults to an empty Set' do
      registry.reset!
      expect(registry.stylesheets).to eq(Hash.new)
    end
  end

  describe '#mobile_stylesheets' do
    it 'defaults to an empty Set' do
      registry.reset!
      expect(registry.mobile_stylesheets).to eq(Hash.new)
    end
  end

  describe '#javascripts' do
    it 'defaults to an empty Set' do
      registry.reset!
      expect(registry.javascripts).to eq(Set.new)
    end
  end

  describe '#auth_providers' do
    it 'defaults to an empty Set' do
      registry.reset!
      expect(registry.auth_providers).to eq(Set.new)
    end
  end

  describe '#admin_javascripts' do
    it 'defaults to an empty Set' do
      registry.reset!
      expect(registry.admin_javascripts).to eq(Set.new)
    end
  end

  describe '#seed_data' do
    it 'defaults to an empty Set' do
      registry.reset!
      expect(registry.seed_data).to be_a(Hash)
      expect(registry.seed_data.size).to eq(0)
    end
  end

  describe '.register_html_builder' do
    it "can register and build html" do
      DiscoursePluginRegistry.register_html_builder(:my_html) { "<b>my html</b>" }
      expect(DiscoursePluginRegistry.build_html(:my_html)).to eq('<b>my html</b>')
      DiscoursePluginRegistry.reset!
      expect(DiscoursePluginRegistry.build_html(:my_html)).to be_blank
    end

    it "can register multiple builders" do
      DiscoursePluginRegistry.register_html_builder(:my_html) { "one" }
      DiscoursePluginRegistry.register_html_builder(:my_html) { "two" }
      expect(DiscoursePluginRegistry.build_html(:my_html)).to eq("one\ntwo")
      DiscoursePluginRegistry.reset!
    end
  end

  describe '.register_css' do
    let(:plugin_directory_name) { "hello" }

    before do
      registry_instance.register_css('hello.css', plugin_directory_name)
    end

    it 'is not leaking' do
      expect(DiscoursePluginRegistry.new.stylesheets[plugin_directory_name]).to be_nil
    end

    it 'is returned by DiscoursePluginRegistry.stylesheets' do
      expect(registry_instance.stylesheets[plugin_directory_name].include?('hello.css')).to eq(true)
    end

    it "won't add the same file twice" do
      expect { registry_instance.register_css('hello.css', plugin_directory_name) }.not_to change(registry.stylesheets[plugin_directory_name], :size)
    end
  end

  describe '.register_js' do
    before do
      registry_instance.register_js('hello.js')
    end

    it 'is returned by DiscoursePluginRegistry.javascripts' do
      expect(registry_instance.javascripts.include?('hello.js')).to eq(true)
    end

    it "won't add the same file twice" do
      expect { registry_instance.register_js('hello.js') }.not_to change(registry.javascripts, :size)
    end
  end

  describe '.register_auth_provider' do
    let(:registry) { DiscoursePluginRegistry }
    let(:auth_provider) do
      provider = Auth::AuthProvider.new
      provider.authenticator = Auth::Authenticator.new
      provider
    end

    before do
      registry.register_auth_provider(auth_provider)
    end

    after do
      registry.reset!
    end

    it 'is returned by DiscoursePluginRegistry.auth_providers' do
      expect(registry.auth_providers.include?(auth_provider)).to eq(true)
    end

  end

  describe '.register_service_worker' do
    let(:registry) { DiscoursePluginRegistry }

    before do
      registry.register_service_worker('hello.js')
    end

    after do
      registry.reset!
    end

    it "should register the file once" do
      2.times { registry.register_service_worker('hello.js') }

      expect(registry.service_workers.size).to eq(1)
      expect(registry.service_workers).to include('hello.js')
    end
  end

  describe '.register_archetype' do
    it "delegates archetypes to the Archetype component" do
      Archetype.expects(:register).with('threaded', hello: 123)
      registry_instance.register_archetype('threaded', hello: 123)
    end
  end

  describe '#register_asset' do
    let(:registry) { DiscoursePluginRegistry }
    let(:plugin_directory_name) { "my_plugin" }

    after do
      registry.reset!
    end

    it "does register general css properly" do
      registry.register_asset("test.css", nil, plugin_directory_name)
      registry.register_asset("test2.css", nil, plugin_directory_name)

      expect(registry.mobile_stylesheets[plugin_directory_name]).to be_nil
      expect(registry.stylesheets[plugin_directory_name].count).to eq(2)
    end

    it "registers desktop css properly" do
      registry.register_asset("test.css", :desktop, plugin_directory_name)

      expect(registry.desktop_stylesheets[plugin_directory_name].count).to eq(1)
      expect(registry.stylesheets[plugin_directory_name]).to eq(nil)
      expect(registry.mobile_stylesheets[plugin_directory_name]).to eq(nil)
    end

    it "registers mobile css properly" do
      registry.register_asset("test.css", :mobile, plugin_directory_name)
      expect(registry.mobile_stylesheets[plugin_directory_name].count).to eq(1)
      expect(registry.stylesheets[plugin_directory_name]).to eq(nil)
    end

    it "registers color definitions properly" do
      registry.register_asset("test.css", :color_definitions, plugin_directory_name)
      expect(registry.color_definition_stylesheets[plugin_directory_name]).to eq('test.css')
      expect(registry.stylesheets[plugin_directory_name]).to eq(nil)
    end

    it "registers admin javascript properly" do
      registry.register_asset("my_admin.js", :admin)

      expect(registry.admin_javascripts.count).to eq(1)
      expect(registry.javascripts.count).to eq(0)
    end

    it "registers vendored_core_pretty_text properly" do
      registry.register_asset("my_lib.js", :vendored_core_pretty_text)

      expect(registry.vendored_core_pretty_text.count).to eq(1)
      expect(registry.javascripts.count).to eq(0)
    end
  end

  describe '#register_seed_data' do
    let(:registry) { DiscoursePluginRegistry }

    after do
      registry.reset!
    end

    it "registers seed data properly" do
      registry.register_seed_data("admin_quick_start_title", "Banana Hosting: Quick Start Guide")
      registry.register_seed_data("admin_quick_start_filename", File.expand_path("../docs/BANANA-QUICK-START.md", __FILE__))

      expect(registry.seed_data["admin_quick_start_title"]).to eq("Banana Hosting: Quick Start Guide")
      expect(registry.seed_data["admin_quick_start_filename"]).to eq(File.expand_path("../docs/BANANA-QUICK-START.md", __FILE__))
    end
  end

end
