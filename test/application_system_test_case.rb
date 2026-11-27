require "test_helper"

# Capybara 3.40.0 clears the browser storage after each test with the origin
# "*". Chrome 158 refuses that origin, so every system test fails at reset.
# This clears all cookies, then the storage of the test server origin. Delete
# it when a Capybara release stops sending "*".
module ClearsStorageOfTestServer
  def execute_cdp(cmd, **params)
    return super unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    super("Network.clearBrowserCookies")
    super(cmd, **params, origin: Capybara.current_session.server.base_url)
  end
end
Capybara::Selenium::Driver::ChromeDriver.prepend(ClearsStorageOfTestServer)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include TrustedTypesViolationsTestHelper

  browser_options = Selenium::WebDriver::Chrome::Options.new.tap do |opts|
    opts.add_argument("--window-size=1200,800")
    opts.add_argument("--disable-extensions")
    # Disable non-foreground tabs from getting a lower process priority
    opts.add_argument("--disable-renderer-backgrounding")
    # Normally, Chrome will treat a 'foreground' tab instead as backgrounded if the surrounding
    # window is occluded (aka visually covered) by another window. This flag disables that.
    opts.add_argument("--disable-backgrounding-occluded-windows")
    # Suppress all permission prompts by automatically denying them.
    opts.add_argument("--deny-permission-prompts")
    opts.add_argument("--enable-automation")
  end

  Capybara.register_driver :chrome_headless do |app|
    browser_options.add_argument("--headless")
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
  end

  Capybara.register_driver :chrome do |app|
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
  end

  if ENV["SYSTEM_TESTS_BROWSER"]
    driven_by :chrome, screen_size: [ 1200, 1000 ]
  else
    driven_by :chrome_headless, screen_size: [ 1200, 1000 ]
  end

  private
    def sign_in_as(user)
      visit session_transfer_url(user.identity.transfer_id, script_name: nil)
      assert_current_path root_path
    end

    def fill_in_lexxy(selector = "lexxy-editor", with:)
      editor_element = find(selector)
      editor_element.set with
      page.execute_script("arguments[0].value = '#{with}'", editor_element)
    end
end
