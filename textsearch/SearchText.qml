import QtQuick 2.9
import QtQuick.Controls 2.2
import MuseScore 3.0
import QtQuick.Window 2.2
import QtQuick.Layouts 1.3


MuseScore {
    readonly property var pluginTitle: qsTr("Search")
    
    menuPath: "Plugins."+pluginTitle
    description: qsTr("Search for text in the current score")
    version: "1.0.0"
    
    property bool searching: false
    
    

    //4.4 title: "Search"
    //4.4 thumbnailName: "logoTextSearch.png"

    Component.onCompleted: {
        if (mscoreMajorVersion >= 4 && mscoreMajorVersion<=3) {
            mainWindow.title = pluginTitle
            mainWindow.thumbnailName = "logoTextSearch.png";
            // mainWindow.categoryCode = "batch-processing";
        }
    }
    
    

    ListModel {
        id: resultsModel
        // ListElement {
        // foundWith: "Foo"
        // type: "Staff text"
        // tick: 123456789
        // element: someElement
        // }
    }
    Window {
        id: mainWindow
        title: pluginTitle
        width: 400
        height: 600
        color: sysActivePalette.button

        ColumnLayout {
            id: mainRow
            anchors.fill: parent
            
            ColumnLayout {
                spacing: 10
                Layout.margins: 10
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    Label {
                        text: qsTr("Search for:")
                        Layout.fillWidth: false
                    }
                    TextField {
                        id: txtSearch
                        placeholderText: qsTr("Search text")
                        Layout.fillHeight: false
                        Layout.fillWidth: true
                        selectByMouse: true
                    }
                }

                CheckBox {
                    id: chkIncludeLineTexts
                    text: qsTr("Include line texts (slower)")
                    Layout.alignment: Qt.AlignLeft
                    checked: false
                }
                
                RowLayout {
                    Label {
                        id: txtCount
                        
                        Layout.fillWidth: true
                        
                        state: (searching?"searching":"finished")
                        
                        states: [
                              State {
                                    name: "finished"
                                    PropertyChanges { 
                                        target: txtCount;
                                        text: (!resultsModel || resultsModel.count===0)?qsTr("No match"):(
                                                    resultsModel.count+" "+qsTr("match(es)"))
                                           } 
                              },
                              State {
                                    name: "searching"
                                    PropertyChanges { target: txtCount; text: qsTr("Searching...") } 
                              }
                        ]
                    }
                
                    CompatibleButton {
                        id: btnSearch
                        text: qsTr("Search")
                        onClicked: search();
                    }
                }


                Rectangle {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 300
                    Layout.fillWidth: true
                    Layout.minimumWidth: 200

                    color: sysActivePalette.base

                    ListView { // Results

                        id: lstResults
                        anchors.fill: parent

                        model: resultsModel

                        //delegate: presetComponent
                        clip: true
                        focus: true

                        Component {
                            id: resultDelegate
                            Rectangle {
                                property var iAmActive: ListView.isCurrentItem

                                color: iAmActive ? sysActivePalette.highlight : "transparent"
                                radius: 2

                                width: lstResults.width
                                height: cvdColumn.childrenRect.height

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        lstResults.currentIndex = index
                                    }
                                    onDoubleClicked: {
                                        gotoResult({
                                            "tick": tick,
                                            "element": element
                                        })
                                    }

                                    ColumnLayout {
                                        id: cvdColumn
                                        spacing: 1
                                        width: parent.width

                                        Label {
                                            id: delLabel
                                            Layout.fillWidth: true

                                            rightPadding: 5
                                            leftPadding: 5
                                            bottomPadding: 0
                                            topPadding: 5

                                            text: foundWith
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                        }
                                        Label {
                                            Layout.fillWidth: true

                                            rightPadding: 5
                                            leftPadding: 5
                                            bottomPadding: 5
                                            topPadding: 0

                                            text: qsTr("Type") + ": " + element.userName() + "\n" + qsTr("At") + ": " + tick

                                            font.pointSize: delLabel.font.pointSize * 0.9

                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                        }

                                    }
                                }
                            }

                        }

                        delegate: resultDelegate

                        highlightMoveDuration: 250 // 250 pour changer la sélection
                        highlightMoveVelocity: 2000 // ou 2000px/sec

                        // scrollbar
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds

                    }

                }

            }
        } // ColumnLayout
        
        Component.onCompleted: {
            txtSearch.focus=true;
        }

        BusyIndicator {
            id: busyIndicator
            x: Math.round((mainWindow.width - width) / 2)
            y: Math.round((mainWindow.height - height) / 2)
            width: 60
            height: 60
            running: searching
            visible: true
        }

    } // ApplicationWindow

    SystemPalette {
        id: sysActivePalette;
        colorGroup: SystemPalette.Active
    }

    function search() {
    
        searching=true;
        searchTimer.restart();

    }
        
    Timer {
        id: searchTimer
        running: false
        repeat: false
        triggeredOnStart: false // je ne veux pas démarrer tout de suite: je laisse qq ms en espérant que l'écran se mettre à jour dans l'interval
        interval: 100

        // this function processes one linked part and
        // gives control back to Qt to update the dialog
        onTriggered: {        
        
            var searchFor = txtSearch.text;
            var alltexts=[];
            
            if (!chkIncludeLineTexts.checked) {
                alltexts=searchByCursor(searchFor);
            }
            else {
                alltexts=searchBySelectAll(searchFor);
            }
            
            // Cleaning and Filtering the results
            console.log("Analyzing " + alltexts.length + " texts elements");

            searchFor = searchFor.toLowerCase();

            alltexts = alltexts.map(function (e) {
                var cleaned = e.foundWith.replace(/[\n\r]/g, ' ');
                e.foundWith = cleaned;
                return e;
            })
                .filter(function (t) {
                return t.foundWith.toLowerCase().includes(searchFor);
            });

            // Pushing to the model
            resultsModel.clear();

            console.log("Found " + alltexts.length + " matching elements");
            for (var i = 0; i < alltexts.length; i++) {
                var info = alltexts[i];
                resultsModel.append(info);
                console.log(i + ") " + info.tick + ", " + info.element.userName() + ", " + info.foundWith);
            }

            searching=false;
            
            
            mainWindow.raise();
        }
    }
    function searchByCursor(searchFor) {
        console.log("Searching by Cursor (FAST)");
        if (curScore==null) return [];
        var score = curScore;
        var cursor = curScore.newCursor();
        var firstTick, firstStaff, lastTick, lastStaff;
        // start
        cursor.rewind(0);
        firstTick = cursor.tick;
        firstStaff = cursor.track;
        // end
        lastTick = curScore.lastSegment.tick + 1;
        lastStaff= curScore.ntracks;
        console.log("getChordsRestsFromScore ** ");
        
        var alltexts = [];

        cursor.rewind(0);
        var segment = cursor.segment;
        while (segment) {
            var annotations = segment.annotations;
            console.log(segment.tick+": "+annotations.length + " annotations");
            if (annotations && (annotations.length > 0)) {
                for (var j = 0; j < annotations.length; j++) {
                    var ann = annotations[j];
                    var textElements=textFromElement(segment.tick,ann);
                    if (textElements) alltexts=alltexts.concat(textElements);
                }
            }
            segment = segment.next; // 18/6/22 : looping thru all segments, and only defined at the curso level (which is bound to track)
        }

        return alltexts;
        
    }


    function searchBySelectAll(searchFor) {
        console.log("Searching by Select All (SLOW)");

        curScore.startCmd(); // startCmd/endCmd around selectRange needed for `selection.elements` to return something
        curScore.selection.selectRange(
            curScore.firstSegment().tick,
            //0,
            curScore.lastSegment.tick + 1, // bug lorsqu'on sélectionne jusqu'à la fin
            0,
            curScore.ntracks);
        curScore.endCmd(); 
        mainWindow.raise(); // je fais revenir la fenêtre au 1er plan
        
        var firstFound;
        var nextFound;
        var elements = curScore.selection.elements;
        console.log(curScore.firstSegment().tick + "/0");
        console.log(curScore.lastSegment.tick + "/" + curScore.ntracks);

        console.log(curScore.selection.isRange);
        console.log(curScore.selection.startSegment.tick);
        console.log(curScore.selection.endSegment); //.tick);
        console.log(elements.length);

        var alltexts = [];

        var prevTick = 0;

        for (var i = 0; i < elements.length; i++) {
            var e = elements[i];
            var tick = tickForElement(e);
            if (tick)
                prevTick = tick;
            else
                tick = prevTick;
            
            var textElements=textFromElement(tick,e);
            if (textElements) alltexts=alltexts.concat(textElements);

        }

        //cmd("undo"); // KO: revert the selectRange required to find the text elements

        return alltexts;

    }
    
    /**
    Retourne une array avec tous les texts trouvés dans cet élémént.
    Retourne undefined si rien n'a été trouvé.
    */
    function textFromElement(tick,e) {
            
            var found=[];
        
            //            console.log(e.userName());
            if (e.type == Element.HARMONY)
                return; // on ne prend pas les accords

            if (e.type == Element.DYNAMIC)
                return; // on ne prend pas les mf, mp, ff, ...

            if (e.type == Element.TEMPO_TEXT) {
                var ttt = e.text.split('=');
                if (ttt.length > 1)
                    return; // don't use tempo expressed as "x=120" pattern
            }

            if (e.beginText) {
                console.log(e.userName() + ": " + e.beginText);
                found.push({
                    element: e,
                    tick: tick,
                    foundWith: e.beginText
                });
            }
            if (e.continueText) {
                console.log(e.userName() + ": " + e.continueText);
                found.push({
                    element: e,
                    tick: tick,
                    foundWith: e.continueText
                });
            }
            if (e.endText) {
                console.log(e.userName() + ": " + e.endText);
                found.push({
                    element: e,
                    tick: tick,
                    foundWith: e.endText
                });
            }
            if (e.glissShowText && e.glissText) {
                console.log(e.userName() + ": " + e.glissText);
                found.push({
                    element: e,
                    tick: tick,
                    foundWith: e.glissText
                });
            }
            if (e.text) {
                console.log(e.userName() + ": " + e.text);
                found.push({
                    element: e,
                    tick: tick,
                    foundWith: e.text
                });
            }
            
            return found;
    }

    function gotoNext() {
        var currSelection = curScore.selection;

        // Searching the point from where to search the search;
        var startPosition;
        if (currSelection && currSelection.elements.length > 0) {
            var el = currSelection.elements[0];
            startPosition = tickForElement(el);
        }
        if (typeof startPosition === "undefined")
            startPosition = -1;

        // Searching for the next occurence

        console.log("Searching for next occurence, from " + startPosition);
        if (resultsModel.count > 0) {
            firstFound = resultsModel.get(0);

            for (var i = 0; i < resultsModel.count; i++) {
                var info = resultsModel.get(i);
                var tick = resultsModel.get(i).tick;
                console.log(i + ") comparing " + tick + " with " + startPosition);
                if (tick > startPosition) {
                    nextFound = info;
                    break;
                }
            }

            if (!nextFound && firstFound) {
                console.log("Can't find a next occurence, taking first occurence");
                nextFound = firstFound;
            }

            gotoResult(nextFound);

        } else {
            // Si rien trouvé, on remet la sélection de départ
            //curScore.selection = currSelection; // warning
        }
        
    }

    function gotoResult(info) {

        console.log("going to " + info.element.userName());

        // Selecting the right element
        // 0) selecting a Note or a Rest at the desired position,
        // because not all elements can be selected
        // and that for a unknown reason, selecting some elements and then applying 
        // the w/a for showing the element, move the element.
        // That does not occur when selecting a Note or a Rest
        var cursor = curScore.newCursor();
        cursor.rewindToTick(info.tick);

        // 0.1) searching the closest Note or Rest from the found element's position
        cursor.track=info.element.track;
        var el = cursor.element;
        cursor.filter = Segment.ChordRest;
        while (el && el.type !== Element.CHORD && el.type !== Element.REST) {
            cursor.next();
            el = cursor.element;
        }

        // 0.2) selcting
        if (el) {
            console.log("position " + el.parent.tick + " - " + info.tick);
            if (el.type === Element.CHORD)
                el = el.notes[0];
            curScore.selection.clear();
            curScore.selection.select(el);
        } else {
            curScore.selection.clear();
            curScore.selection.select(info.element);
        }
        
        // Moving the viewport
        // this codes moves the viewport to the selection, but the selection changes to the current note/rest
        cmd("reset"); // Repaint canvas.
        cmd("note-input"); // Janky code. X(
        //cmd("note-input"); // orig w/a
        cmd("escape"); // my w/a

        
        // Reselecting the right element if possible
        // known element types that can't be selected: TextLine, Glissando
        if (info.element.type !== Element.TEXTLINE && info.element.type !== Element.GLISSANDO) {
            curScore.selection.clear();
            curScore.selection.select(info.element);
        }
    }
    onRun: {
        mainWindow.show()
    }
    // onRun


    function segmentForElement(element) {
        var el = element;
        console.log("[searching for Segment]" + el.userName());
        while (el && el.type !== Element.SEGMENT) {
            el = el.parent;
            console.log("[searching for Segment]" + (el ? el.userName() : "/"));
        }

        return el;
    }

    function tickForElement(element) {
        var el = segmentForElement(element);
        console.log("[searching for tick]" + (el ? el.userName() : "/"));

        if (el) {
            console.log("[searching for tick]" + el.tick);
            return el.tick;
        }
        return undefined;
    }

}
