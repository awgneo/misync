Overview
This article provides an introduction to Quick App cards, their use cases, and the relationship between cards and Quick Apps.

Through this section, you will become familiar with:

Introduction
Use cases
The relationship and differences between cards and quick apps
#Introduction
Quick App cards are built on the Quick App technology stack and can be seamlessly embedded into native applications as part of their interface.

Although Quick App cards use the same technology stack as Quick Apps, their functionality is relatively limited, containing only a selected subset of Quick App capabilities. To ensure accuracy during development and the achievement of expected functionality, please refer to the detailed capability descriptions listed in this document.

The following document describes Quick App cards as cards.

#Use cases
The card supports embedding in various display scenarios, including: the negative one screen, desktop, full search, lock screen, browser, and voice assistant.

Negative one screen
#The relationship and differences between cards and quick apps
1. A Quick App project can contain one or more cards;

2. The project may contain only cards and not quick app pages;

3. Cards and quick apps with the same signature and package name can share local data stored using the system.storage interface for reading and writing;

4. Cards do not support page stacks and do not support navigation between cards;

5. Different cards are displayed in isolation during runtime, and cards cannot communicate with each other;

6. Cards are loaded and rendered independently and do not depend on quick apps. Scripts defined in app.ux in the project will not be loaded by the runtime environment. Therefore, cards cannot access common capability components defined in app.ux, nor can they access objects such as $app and $page.

7. When multiple cards in the same project directory are uploaded, the platform will manifest.jsonsplit the cards into independent RPKs and distribute them to the corresponding scenarios (such as the negative one screen or the desktop) according to the card routing configuration.

Project Structure
cell phone
watch
This article explains the project's structure and related aspects, including the card quick app file structure, configuration, and adding cards.

In this section, you will learn:

Project Introduction
Configuration information
Add a quick app page
New Cards
Hybrid Engineering
Resource Reference
Introduce dependencies
#Project Introduction
Create a new project through the IDE. This project already includes project configuration , sample pages , and initial code for card files . The main structure of the project root directory is as follows:

├── sign                      rpk包签名模块
│   ├── certificate.pem       证书文件
│   └── private.pem           私钥文件
├── src
│   |—— Card                  卡片代码和资源目录
|   |   └── index.ux          卡片页面文件
│   ├── Common                公用的资源和组件文件
│   │   └── logo.png          应用图标
│   ├── Demo                  快应用页面目录
│   |   └── index.ux          页面文件，可自定义页面名称
│   ├── app.ux                APP文件
│   └── manifest.json         项目配置文件，配置应用图标、页面路由等
└── package.json              定义项目需要的各种模块及配置信息
A brief description of the table of contents is as follows:

src : Project source folder
sign : Signature module. For details on signature generation methods, please refer to the certificate generation documentation.(opens a new window)
#New Cards
Adding and configuring cards requires configuration manifest.jsonin the dependencies.router.widgets

#router.widgets
Cards are defined using the router.widgets field in manifest.json.

property	type	Required	illustrate
widgets	Object	no	The card list uses the following key: the card name (corresponding to the card directory name, e.g., cards/Card cards/Card, where /<key value> is the card access path and a unique identifier for the card), and the value is the card's detailed configuration widget, as detailed below.
#widget detailed description
property	type	Required	describe
name	String	yes	Card Name (Enter this field with caution, as it may be displayed, for example, in the notification bar)
description	String	no	Card Description (Please fill in this field carefully, as it may be displayed)
component	String	yes	The component name corresponding to the card should be consistent with the ux file name, for example, 'card' corresponds to 'card.ux'.
features	Array	no	The list of interfaces used by this card is defined separately and can be requested in advance in certain scenarios (e.g., the negative one screen).
minCardPlatformVersion	Integer	yes	Minimum supported card platform version number注意：卡片minCardPlatformVersion版本号字段有别于快应用的minPlatformVersion，具体支持的卡片平台版本号请参考本文档所列
targetManufacturers	Array	no	Target Manufacturer (Optional): If this field is configured, the corresponding manufacturer must be specified. Failure to specify may result in the app not being able to list on the corresponding manufacturer's site. Currently supported manufacturer fields are: "vivo", "OPPO", "xiaomi", and "honor".
sizes	Array	yes	The card supports various appearance size options, each representing the component's footprint (width and height, in grid cells) within the layout grid. Combinations of "FULL"(full width/full height), "AUTO"(width/height auto-adjustable), and specific values ​​are supported and defined using formats such as `<size> "2x2"`, "FULLx4"`<width>`, "1xFULL"`<height> "4xAUTO"`, and `<grid>`. Refer to the respective vendor's entry point support for configuration settings.
deviceTypeList	Array	no	The types of devices the card supports. Optional values ​​are: phone, watch, The default value is .phone
The widgets field is defined in the router field. For example, if the card source file is in src/cards/card/index.ux, then the widgets definition is as follows.

{
  "router": {
    "widgets": {
      "cards/card": {
        "name": "卡片",
        "description": "这是一个快应用卡片",
        "component": "index",
        "features": [
          {
            "name": "system.network"
          },
          {
            "name": "system.router"
          }
        ],
        "minCardPlatformVersion": 2000,
        "targetManufacturers": ["vivo", "OPPO", "xiaomi", "honor"],
        "sizes": ["2x2","2x1"],
        "deviceTypeList": ["phone","watch"]
      }
    }
  }
}
注意：其中卡片 key 值应为卡片存放目录“cards/card”，仅允许字母、数字、“_”和“/”组成，使用特殊字符可能导致编译失败或无法上传审核平台。

#Hybrid Engineering
In a project, pages or widgets configurations can exist independently or simultaneously (cards and quick apps can coexist), and multiple cards can be configured within widgets, as shown in the example below:

{
  "router": {
    "pages": {
      "Demo": {
        "component": "index"
      }
    },
    "widgets": {
      "cards/card_one": {
        "name": "卡片1",
        "description": "这是一个快应用卡片",
        "component": "index",
        "features": [
          {
            "name": "system.network"
          },
          {
            "name": "system.router"
          }
        ],
        "minCardPlatformVersion": 2000,
        "targetManufacturers": ["vivo", "OPPO", "xiaomi", "honor"],
        "sizes": ["2x1"],
        "deviceTypeList": ["phone","watch"]
      },
      "cards/card_two": {
        "name": "卡片2",
        "description": "这是一个快应用卡片",
        "component": "index",
        "features": [
          {
            "name": "system.network"
          },
          {
            "name": "system.router"
          }
        ],
        "minCardPlatformVersion": 2000,
        "targetManufacturers": ["vivo", "OPPO", "xiaomi", "honor"],
        "sizes": ["2x2"],
        "deviceTypeList": ["phone","watch"]
      }
    }
  }
}
#Resource Reference
Local resources used by the card, such as images and multilingual configuration files, need to be placed in their respective card directories; otherwise, they cannot be referenced. For example, cards/card_onethe images and multilingual resources used in the above example must be placed in cards/card_onethe card's directory; placing them in other directories will not work.

#Introduce dependencies
For information on adding dependencies, please refer to the official documentation .

life cycle
cell phone
watch
Understanding the Card Lifecycle

In this section, you will learn:

Card lifecycle
#Card lifecycle
Since cards are ViewModelrendered, the card lifecycle refers to ViewModelthe lifecycle of the application, including common methods such as onInit, onReady, and onShow, which are triggered when the card page is created .

#onInit()
The ViewModeldata is ready ; you can start using the data on the page.

Example as follows:

data: {
  // 生命周期的文本列表
  lcList: []
},
onInit () {
  this.lcList.push('onInit')

  console.info(`触发：onInit`)
  console.info(`执行：获取ViewModel的lcList属性：${this.lcList}`)   // 执行：获取ViewModel的lcList属性：onInit
}
#onReady()
The ViewModeltemplate has been compiled and you can start retrieving DOM nodes (e.g., this.$element(idxxx)).

Example as follows:

onReady () {
  this.lcList.push('onReady')

  console.info(`触发：onReady`)
  // 执行：获取模板节点：<div attr={} style={"flexDirection":"column"}>...</div>
  console.info(`执行：获取模板节点`)
}
#onShow(), onHide()
The app can run multiple pages simultaneously, but only one page can be displayed at a time . This differs from pure front-end development, where only one page can be displayed at a time in a browser; when a new page is opened from the current tab, the previous page is destroyed. However, it is somewhat similar to SPA development, where the browser's global context is shared when switching pages.

Therefore, page switching generates new events: onHide() is called when the page is hidden and onShow() is called when the page is shown again.

Example as follows:

onShow () {
  this.lcList.push('onShow')
},
onHide () {
  console.info(`触发：onHide`)
}
#onDestroy()
This function is invoked when a card is destroyed, so some resource release operations should be performed during destruction.

Example as follows:

onDestroy () {
  console.info(`触发：onDestroy`)
  setTimeout(() => {
    // 页面已销毁，不会执行
    console.info(`执行：卡片已被销毁，不会执行`)
  }, 0)
}