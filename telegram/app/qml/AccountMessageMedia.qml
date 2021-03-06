import QtQuick 2.4
import Ubuntu.Components 1.3

import AsemanTools 1.0
import TelegramQML 1.0
import QtGraphicalEffects 1.0

import "components"
import "ui"

Item {
    id: msg_media

    property Message message
    property MessageMedia media: message.media
    property bool hasMedia: file_handler.targetType != FileHandler.TypeTargetUnknown &&
                            file_handler.progressType != FileHandler.TypeProgressUpload
    property variant mediaType: file_handler.targetType
    property bool downloading: file_handler.progressType != FileHandler.TypeProgressEmpty
    property alias mediaWidth: file_handler.imageSize.width
    property alias mediaHeight: file_handler.imageSize.height

    property real maximumMediaHeight: units.gu(24)
    property real minimumMediaHeight: units.gu(16)
    property real maximumMediaWidth: parent.width
    property real maximumMediaRatio: maximumMediaWidth / maximumMediaHeight

    property variant msgDate: CalendarConv.fromTime_t(message.date)
    property alias location: file_handler.filePath

    property alias isSticker: file_handler.isSticker

    property bool showStatus: true

    property variant mediaPlayer
    property bool isAudioMessage: file_handler.targetType == FileHandler.TypeTargetMediaAudio
    onIsAudioMessageChanged: {
        if(isAudioMessage) {
            if(mediaPlayer)
                mediaPlayer.destroy()
            mediaPlayer = media_player_component.createObject(msg_media)
        } else {
            if(mediaPlayer)
                mediaPlayer.destroy()
            mediaPlayer = 0
        }
    }

    signal mediaClicked(int type, string path);

    width: {
        var result
        if(mediaPlayer)
            return mediaPlayer.width
        if(file_handler.progressType == FileHandler.TypeProgressUpload)
            return 0
        // Prevent empty website image preview.
        if (media_img.source == 0)
            return 0;

        switch( file_handler.targetType )
        {
        case FileHandler.TypeTargetMediaVideo:
        case FileHandler.TypeTargetMediaPhoto:
            result = mediaWidth > mediaHeight?
                        Math.min(mediaWidth, maximumMediaWidth):
                        mediaWidth * Math.min(1, maximumMediaHeight / mediaHeight)
            break;
        case FileHandler.TypeTargetUnknown:
        case FileHandler.TypeTargetMediaAudio:
        case FileHandler.TypeTargetMediaDocument:
            result = isSticker ? units.gu(20) : units.gu(17)
            break;
        case FileHandler.TypeTargetMediaGeoPoint:
            result = mapDownloader.size.width
            break;
        default:
            result = 0
            break;
        }
        return result
    }

    height: {
        var result
        if(mediaPlayer)
            return mediaPlayer.height
        if(file_handler.progressType == FileHandler.TypeProgressUpload)
            return 0
        // Prevent empty website image preview.
        if (media_img.source == 0)
            return 0;

        switch( file_handler.targetType )
        {
        case FileHandler.TypeTargetMediaVideo:
        case FileHandler.TypeTargetMediaPhoto:
            result = mediaHeight >= mediaWidth?
                        Math.min(mediaHeight, maximumMediaHeight):
                        Math.max(mediaHeight * Math.min(1, maximumMediaWidth / mediaWidth), minimumMediaHeight)
            break;
        case FileHandler.TypeTargetMediaAudio:
            result = 0;
            break;
        case FileHandler.TypeTargetUnknown:
        case FileHandler.TypeTargetMediaDocument:
            result = isSticker ? width*media_img.imageSize.height/media_img.imageSize.width : width
            break;
        case FileHandler.TypeTargetMediaGeoPoint:
            result = mapDownloader.size.height
            break;
        default:
            result = 0
            break;
        }
        return result
    }

    property string fileLocation: file_handler.filePath

    FileHandler {
        id: file_handler
        telegram: telegramObject
        target: message
        defaultThumbnail: "image://theme/stock_document"
        onTargetTypeChanged: {
            switch(targetType)
            {
            case FileHandler.TypeTargetMediaDocument:
                if(isSticker)
                    download()
                break;

            case FileHandler.TypeTargetMediaPhoto:
                download()
                break;

            case FileHandler.TypeTargetMediaGeoPoint:
                mapDownloader.addToQueue(Qt.point(message.media.geo.lat, message.media.geo.longitude), media_img.setImage )
            }
        }
    }

    Image {
        id: media_img
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        visible: file_handler.targetType != FileHandler.TypeTargetMediaVideo || fileLocation.length != 0

        property size imageSize: Cutegram.imageSize(source)
        property string customImage

        source: {
            var result = ""
            switch( file_handler.targetType )
            {
            case FileHandler.TypeTargetMediaPhoto:
                result = file_handler.filePath
                break;

            case FileHandler.TypeTargetMediaVideo:
                result = file_handler.thumbPath
                break;

            case FileHandler.TypeTargetUnknown:
            case FileHandler.TypeTargetMediaAudio:
                break;

            case FileHandler.TypeTargetMediaDocument:
                if(isSticker) {
                    result = fileLocation
                    if(result.length==0)
                        result = file_handler.thumbPath
                }
                else
                if(Cutegram.fileIsImage(file_handler.filePath))
                    result = fileLocation
                else
                    result = file_handler.thumbPath
                break;

            case FileHandler.TypeTargetMediaGeoPoint:
                result = customImage
                break;
            }

            return result
        }

        function setImage(img) {
            customImage = img
        }
    }


    Rectangle {
        anchors {
            leftMargin: units.dp(-4)
            rightMargin: units.dp(-5)
            topMargin: units.dp(-1)
            bottomMargin: units.dp(-1)
            fill: filename_lbl
        }
        color: Qt.rgba(0, 0, 0, 0.3)
        radius: units.dp(2)
        visible: filename_lbl.text !== ""
    }

    Label {
        id: filename_lbl
        anchors.top: parent.top
        anchors.left: parent.left
        font.weight: Font.DemiBold
        fontSize: "small"
        color: "white"
        visible: !download_frame.visible
        text: {
                if (!isSticker && !Cutegram.fileIsImage(file_handler.filePath))
                    return file_handler.fileName;
                else
                    return "";
        }
    }

    FastBlur {
        anchors.fill: media_img
        source: media_img
        radius: 32
        visible: !media_img.visible
    }

    Rectangle {
        id: video_frame
        color: "#44000000"
        visible: file_handler.targetType == FileHandler.TypeTargetMediaVideo && fileLocation.length != 0
        anchors.fill: media_img

        Icon {
            width: units.gu(6)
            height: width
            name: video_frame.visible ? "media-playback-start" : "" //don't know where to test it
            anchors.centerIn: parent
        }
    }

    Rectangle {
        id: download_frame
        anchors.fill: parent
        color: "#88000000"
        visible: fileLocation.length == 0 && !isSticker
                && file_handler.targetType != FileHandler.TypeTargetMediaPhoto
                && file_handler.targetType != FileHandler.TypeTargetMediaGeoPoint
        radius: units.dp(4)

        Icon {
            height: units.gu(4)
            width: height
            anchors.centerIn: parent
            color: "white"
            name: {
                if (mediaType == FileHandler.TypeTargetUnknown) {
                    return "cancel"; // indicating error
                } else {
                    return "save";
                }
            }
            visible: !downloading
        }

        Rectangle {
            anchors {
                leftMargin: units.dp(-4)
                rightMargin: units.dp(-5)
                topMargin: units.dp(-1)
                bottomMargin: units.dp(-1)
                fill: filesize_lbl
            }
            color: Qt.rgba(0, 0, 0, 0.3)
            radius: units.dp(2)
        }

        Label {
            id:filesize_lbl
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: units.gu(0.5)
            font.weight: Font.DemiBold
            fontSize: "small"
            color: "white"
            text: {
                if(downloading)
                    return uploadedSize + " / " + totalSize;
                else
                    return file_handler.filename == "" ? totalSize : file_handler.fileName + "\n" + totalSize;
            }

            property string totalSize: Math.floor(file_handler.fileSize/(10485.76))/100 + "MB"
            property string uploadedSize: Math.floor(file_handler.progressCurrentByte/(10485.76))/100 + "MB"

        }
    }

    ProgressBar {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: units.gu(0.5)
        height: units.dp(3)
        radius: 0
        percent: downloading ? file_handler.progressPercent : 0
        visible: downloading
    }

    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        source: file_handler.targetType == FileHandler.TypeTargetMediaOther? "files/map-pin.png" : ""
        sourceSize: Qt.size(width,height)
        fillMode: Image.PreserveAspectFit
        width: units.gu(12)
        height: units.gu(12)
        visible: file_handler.targetType == FileHandler.TypeTargetMediaOther
        asynchronous: true
        smooth: true
    }

    MessageStatus {
        id: message_status
        objectName: "mediaMessageStatus"
        anchors {
            bottom: parent.bottom
            bottomMargin: units.dp(4)
            right: parent.right
            rightMargin: units.dp(4)
        }
        visible: msg_media.showStatus

        message: msg_media.message
        hasMedia: msg_media.hasMedia
    }

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        height: units.gu(4)
        width: height
        color: "white"
        name: "cancel"
        visible: downloading && file_handler.targetType != FileHandler.TypeTargetMediaPhoto && !isSticker

        MouseArea {
            anchors.fill: parent
            onClicked: file_handler.cancelProgress()
        }
    }

    function click() {
        if (fileLocation.length != 0) {
            msg_media.mediaClicked(mediaType, fileLocation);
        }
        else
        {
            switch( file_handler.targetType )
            {
            case FileHandler.TypeTargetMediaVideo:
            case FileHandler.TypeTargetMediaPhoto:
            case FileHandler.TypeTargetMediaDocument:
            case FileHandler.TypeTargetMediaAudio:
                file_handler.download()
                break;

            case FileHandler.TypeTargetMediaGeoPoint:
                //Qt.openUrlExternally( mapDownloader.webLinkOf(Qt.point(media.geo.lat, media.geo.longitude)) )
                break;

            default:
                return false
            }
        }

        return true
    }

    Component {
        id: media_player_component
        MediaPlayerItem {
            width: units.gu(22)
            height: units.gu(5)
            anchors.verticalCenter: parent.verticalCenter
            filePath: fileLocation
            z: fileLocation.length == 0? -1 : 0

            MouseArea {
                anchors.fill: parent
                visible: fileLocation.length == 0
                onClicked: msg_media.click()
            }
        }
    }
}
