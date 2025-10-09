package main.java.ingestion;

import com.marklogic.client.DatabaseClient;
import com.marklogic.client.DatabaseClientFactory;
import com.marklogic.client.datamovement.DataMovementManager;
import com.marklogic.client.datamovement.WriteBatcher;
import com.marklogic.client.io.StringHandle;
import com.marklogic.client.DatabaseClientFactory.Authentication;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public class XmlWriter {
    private static final int MAX_RETRIES = 2;

    private final DatabaseClient client;
    private final DataMovementManager moveMgr;
    private final WriteBatcher batcher;
    // data structure to store the number of retries executed for each batch
    private final Map<Integer, Integer> batchRetries;

    public XmlWriter(String host, int port, String user, String password, String database) {
        this.client = DatabaseClientFactory.newClient(
                host, port, user, password, Authentication.DIGEST
        );
        this.moveMgr = client.newDataMovementManager();
        
        this.batchRetries = new ConcurrentHashMap<>();
        this.batcher = moveMgr.newWriteBatcher()
                .withBatchSize(1)
                .withThreadCount(1)
                .onBatchSuccess(batch-> {
                    baatchRetries.remove(batch.getJobRecordNumber());
                    System.out.println("Batch Success: " + batch.getJobWritesSoFar() + " documents written at " + batch.getTimestamp());
                    // TODO: we need to send a signal to the main thread so it can register this batch as completed
                })
                .onBatchFailure((batch, throwable) -> {
                    if (batchRetries.get(batch.getJobRecordNumber()) < MAX_RETRIES) {
                        int retries = batchRetries.getOrDefault(batch.getJobRecordNumber(), 0) + 1;
                        
                        // add waiting time before retrying
                        try {
                            Thread.sleep(retries * 5000L);
                        } catch (InterruptedException e) {
                            Thread.currentThread().interrupt();
                        }

                        System.err.println("Retrying batch with id " + batch.getJobRecordNumber() + " with " + batch.getItems().size() + " items");
                        batchRetries.put(batch.getJobRecordNumber(), retries);
                        batch.retryWithFailureListeners(batch);
                    } else {
                        System.err.println("Batch failed after" + MAX_RETRIES + " attempts: " + throwable.getMessage());
                        // TODO: should we throw an exception here to stop the job?
                    }
                });;
    }

    /**
     * Pushes a map of XML documents to MarkLogic.
     * @param xmlDocuments Map of URI to XML string.
     */
    public void pushXmlDocuments(Map<String, String> xmlDocuments) {
        for (Map.Entry<String, String> entry : xmlDocuments.entrySet()) {
            String uri = entry.getKey();
            String xml = entry.getValue();
            batcher.add(uri, new StringHandle(xml).withFormat(com.marklogic.client.io.Format.XML));
        }
    }

    /**
     * Starts the Data Movement job to write documents and waits for completion.
     */
    public void startJob() {
        moveMgr.startJob(batcher);
    }

    public void close() {
        batcher.flushAndWait();
        moveMgr.stopJob(batcher);

        if (client != null) {
            client.release();
        }
    }
}
