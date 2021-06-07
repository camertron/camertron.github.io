require_relative "./helper"
class TestFeed < Minitest::Test
  context "feed" do
    setup do
      @page = site.pages.find { |doc| doc.url == "/feed.xml" }
    end
    should "exist" do
      assert @page.present?
      # The feed should not render with a
      # layout since it is just a text document.
      assert @page.no_layout?
    end
  end
end
