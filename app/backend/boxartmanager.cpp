#include "boxartmanager.h"
#include "../path.h"

#include <QImageReader>
#include <QImageWriter>

BoxArtManager::BoxArtManager(QObject *parent) :
    QObject(parent),
    m_BoxArtDir(Path::getBoxArtCacheDir()),
    m_ThreadPool(this)
{
    // 4 is a good balance between fast loading for large
    // app grids and not crushing GFE with tons of requests
    // and causing UI jank from constantly stalling to decode
    // new images.
    m_ThreadPool.setMaxThreadCount(4);
    if (!m_BoxArtDir.exists()) {
        m_BoxArtDir.mkpath(".");
    }
}

QString
BoxArtManager::getFilePathForBoxArt(const QString& computerUuid, int appId)
{
    QDir dir = m_BoxArtDir;

    // Create the cache directory if it did not already exist
    if (!dir.exists(computerUuid)) {
        dir.mkdir(computerUuid);
    }

    // Change to this computer's box art cache folder
    dir.cd(computerUuid);

    // Try to open the cached file
    return dir.filePath(QString::number(appId) + ".png");
}

// Copies everything it needs from the host up front, because the host can be deleted
// while the fetch is running. The NvComputer pointer is only passed back as an identifier.
class NetworkBoxArtLoadTask : public QObject, public QRunnable
{
    Q_OBJECT

public:
    NetworkBoxArtLoadTask(BoxArtManager* boxArtManager, NvComputer* computer, NvApp& app)
        : m_Computer(computer),
          m_App(app)
    {
        {
            QReadLocker lock(&computer->lock);
            m_Address = computer->activeAddress;
            m_HttpsPort = computer->activeHttpsPort;
            m_ServerCert = computer->serverCert;
            m_UseTrueUid = !computer->isNvidiaServerSoftware;
            m_Uuid = computer->uuid;
        }

        m_CachePath = boxArtManager->getFilePathForBoxArt(m_Uuid, m_App.id);

        connect(this, &NetworkBoxArtLoadTask::boxArtFetchCompleted,
                boxArtManager, &BoxArtManager::handleBoxArtLoadComplete);
    }

signals:
    void boxArtFetchCompleted(NvComputer* computer, NvApp app, QUrl image);

private:
    void run()
    {
        QUrl image = loadFromNetwork();
        if (image.isEmpty()) {
            // Give it another shot if it fails once
            image = loadFromNetwork();
        }
        emit boxArtFetchCompleted(m_Computer, m_App, image);
    }

    QUrl loadFromNetwork()
    {
        if (m_Address.isNull()) {
            return QUrl();
        }

        NvHTTP http(m_Address, m_HttpsPort, m_ServerCert, m_UseTrueUid);

        QImage image;
        try {
            image = http.getBoxArt(m_App.id);
        } catch (...) {}

        // Cache the box art on disk if it loaded
        if (!image.isNull()) {
            if (image.save(m_CachePath)) {
                return QUrl::fromLocalFile(m_CachePath);
            }
            else {
                // A failed save() may leave a zero byte file. Make sure that's removed.
                QFile(m_CachePath).remove();
            }
        }

        return QUrl();
    }

    NvComputer* m_Computer;
    NvApp m_App;
    NvAddress m_Address;
    uint16_t m_HttpsPort;
    QSslCertificate m_ServerCert;
    bool m_UseTrueUid;
    QString m_Uuid;
    QString m_CachePath;
};

QUrl BoxArtManager::loadBoxArt(NvComputer* computer, NvApp& app)
{
    // Try to open the cached file if it exists and contains data
    QString uuid;
    {
        QReadLocker lock(&computer->lock);
        uuid = computer->uuid;
    }

    QFile cacheFile(getFilePathForBoxArt(uuid, app.id));
    if (cacheFile.exists() && cacheFile.size() > 0) {
        return QUrl::fromLocalFile(cacheFile.fileName());
    }

    // If we get here, we need to fetch asynchronously.
    // Kick off a worker on our thread pool to do just that.
    NetworkBoxArtLoadTask* netLoadTask = new NetworkBoxArtLoadTask(this, computer, app);
    m_ThreadPool.start(netLoadTask);

    // Return the placeholder then we can notify the caller
    // later when the real image is ready.
    return QUrl("qrc:/res/no_app_image.png");
}

void BoxArtManager::deleteBoxArt(NvComputer* computer)
{
    QDir dir(Path::getBoxArtCacheDir());

    // Delete everything in this computer's box art directory
    if (dir.cd(computer->uuid)) {
        dir.removeRecursively();
    }
}

void BoxArtManager::handleBoxArtLoadComplete(NvComputer* computer, NvApp app, QUrl image)
{
    if (!image.isEmpty()) {
        emit boxArtLoadComplete(computer, app, image);
    }
}

#include "boxartmanager.moc"
