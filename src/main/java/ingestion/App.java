package main.java.ingestion;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Map;
import java.util.HashMap;

import com.moandjiezana.toml.Toml;

public class App {
    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: java App <config-file.toml>");
            System.exit(1);
        }

        String configPath = args[0];

        Toml toml;
        try {
            toml = new Toml().read(Files.newInputStream(Paths.get(configPath)));
        } catch (IOException e) {
            System.err.println("Failed to read config file: " + e.getMessage());
            return;
        }

        String host = toml.getString("marklogic.host");
        int port = toml.getLong("marklogic.port").intValue();
        String user = toml.getString("marklogic.user");
        String password = toml.getString("marklogic.password");
        String database = toml.getString("marklogic.database");
        String xmlDir = toml.getString("xml_directory");

        XmlWriter writer = new XmlWriter(host, port, user, password, database);

        try {
            Map<String, String> xmlDocs = new HashMap<>();
            Files.list(Paths.get(xmlDir))
                .filter(path -> path.toString().endsWith(".xml"))
                .forEach(path -> {
                    try {
                        String content = Files.readString(path);
                        String fileName = path.getFileName().toString();
                        String baseName = fileName.substring(0, fileName.lastIndexOf('.'));
                        String uri = baseName.replace('_', '/');
                        xmlDocs.put(uri, content);
                    } catch (IOException e) {
                        System.err.println("Failed to read file: " + path + " - " + e.getMessage());
                    }
                });
            writer.startJob();
            writer.pushXmlDocuments(xmlDocs);
        } catch (IOException e) {
            System.err.println("Error reading XML files: " + e.getMessage());
        } finally {
            writer.close();
        }
    }
}
