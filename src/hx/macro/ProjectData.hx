package hx.macro;

#if macro
class ProjectData {
	public function new() {
		var xml:Xml = Xml.parse(sys.io.File.getContent("project.xml"));
		trace("xml=", xml);
	}
}
#end
