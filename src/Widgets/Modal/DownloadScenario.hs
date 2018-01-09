{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}

module Widgets.Modal.DownloadScenario
    ( popupDownloadScenario
    , prepareDownloadScenarioContent
    , downloadScenario
    ) where

import Reflex.Dom
import Text.Julius (julius, rawJS)
import Language.Haskell.TH
import Control.Lens

import Commons
import Model.Scenario (Scenario)
import qualified Model.Scenario as Scenario
import Model.GeoJSON.Scenario () -- toJSON instance for Scenario
import JavaScript.JSON.Types.Instances (toJSON)
import Widgets.Commons
import Widgets.Generation
import Widgets.Modal


popupDownloadScenario :: Reflex t
                      => Behavior t Scenario
                      -> Event t (ElementClick downloadScenarioButton)
                      -> QuaWidget t x ()
popupDownloadScenario scB scContentPopupE
  = void $ createSmallModalWithClicks' scContentPopupE Inactive
         $ downloadScenarioContent scB scContentPopupE

prepareDownloadScenarioContent :: MonadIO m
                               => Scenario
                               -> m ()
prepareDownloadScenarioContent sc = do
  void prepareFns
  liftIO $ (jsonStringify $ toJSON sc) >>= js_makeScenarioContentUrl

downloadScenario :: Text
downloadScenario = "document['q$downloadScenarioContentUrl']();"

downloadScenarioContent :: Reflex t
                        => Behavior t Scenario
                        -> Event t (ElementClick downloadScenarioButton)
                        -> QuaWidget t x (Event t (ElementClick "Close Submit Proposal Modal"))
downloadScenarioContent scB scContentPopupE = do
    nameFieldId <- prepareFns
    -- save scenario into globally defined url every time this event happens
    performEvent_ $ liftIO . (>>= js_makeScenarioContentUrl) . jsonStringify . toJSON
                 <$> scB <@ scContentPopupE

    elClass "div" "modal-heading" $
      elClass "p" "modal-title" $ text "Download scenario geometry"
    _ <- elClass "div" "modal-inner" $
      elClass "div" "form-group form-group-label" $ do
        elAttr "label" (("class" =: "floating-label") <> ("for" =: nameFieldId))
          $ text "File name"
        textInput
          $ def & attributes .~ constDyn (("class" =: "form-control") <> ("id" =: nameFieldId))
                & setValue .~ (view (Scenario.name.non "".to textFromJSString)
                               <$> scB <@ scContentPopupE)
    elClass "div" "modal-footer" $
      elClass "p" "text-right" $ do
        ce <- buttonFlat "Close" def
        se <- buttonFlat "Download" $ "onclick" =: downloadScenario
        return $ leftmost [ce, se]

prepareFns :: MonadIO m => m Text
prepareFns = do
  let (runCode, nameFieldId) = $(do
        nameFId <- newVar
        scenarioContentUrl <- newVar
        exportVars <- returnVars [nameFId]
        let scurl = rawJS scenarioContentUrl
        runCode' <- qjs
          [julius|
              var #{scurl} = null;
              document['q$makeScenarioContentUrl'] = function(txt) {
                  if (#{scurl} !== null) {
                    window.URL.revokeObjectURL(#{scurl});
                  }
                  #{scurl} = window.URL.createObjectURL
                      (new Blob([txt], {type: 'application/json;charset=utf-8'}));
              };
              document['q$downloadScenarioContentUrl'] = function() {
                  var a = document.createElement("a");
                  a.href = #{scurl};
                  var nameInput = document.getElementById('#{rawJS nameFId}');
                  a.download = (nameInput ? nameInput.value : "qua-kit") + ".scenario";
                  document.body.appendChild(a);
                  a.click();
                  document.body.removeChild(a);
              };
          |]
        return $ ConE (tupleDataName 2) `AppE` runCode' `AppE` exportVars
        )
  runCode
  return nameFieldId

foreign import javascript "document['q$makeScenarioContentUrl']($1);"
  js_makeScenarioContentUrl :: JSString -> IO ()
