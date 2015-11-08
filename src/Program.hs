-----------------------------------------------------------------------------
-- |
-- Module      :  Program
-- Copyright   :  (c) Artem Chirkin
-- License     :  BSD3
--
-- Maintainer  :  Artem Chirkin <chirkin@arch.ethz.ch>
-- Stability   :  experimental
--
--
--
-----------------------------------------------------------------------------

module Program where

--import GHCJS.Foreign
--import GHCJS.Marshal
--import Program.Model.GeoJSON


import JavaScript.Web.Canvas (Canvas)
import GHCJS.WebGL
import GHCJS.Useful
import Data.Geometry
----import Geometry.Structure (Polygon(..))
--
--import Controllers.LuciClient
--
import Program.Model.Camera
import Program.Model.City
import Program.Model.CityObject
import Program.Model.WiredGeometry
import Program.View.CityView ()
import Program.View.WiredGeometryView ()
import Program.View

--import Services
--import Services.RadianceService
--import Services.Isovist

data Profile = Full | ExternalEditor | ExternalViewer deriving (Show, Eq)

-- | Data type representing the whole program state
data Program = Program
--    {
--    --, info     :: !Info
    { camera   :: !Camera
    , decGrid  :: !WiredGeometry
    , city     :: !City
    , userRole :: !Profile
    , controls :: !Controls
    }

data Controls = Controls
    { selectedObject     :: !Int
--    , activeService      :: !ServiceBox
--    , availableServices  :: ![ServiceBox]
--    , placeTransform     :: !(Maybe (GLfloat, Vector2 GLfloat))
    }
--
----data Info = Info
----    { geomUpdateTime   :: !GLfloat
----    , geomUpdateAmount :: !Int
----    }
----
----infoDef :: Info
----infoDef = Info
----    { geomUpdateTime   = 0
----    , geomUpdateAmount = 0
----    }
--
--initProgram userProfile = Program
--    { controls = Controls
--        { selectedObject = 0
--        }
--    --, info = infoDef
--    , userRole = userProfile
--    }
initProgram :: GLfloat -- ^ width of the viewport
            -> GLfloat -- ^ height of the viewport
            -> CState -- ^ initial camera state
            -> Profile -- ^ determine the functionality of the program
            -> Program
initProgram vw vh cstate userProfile = Program
    { camera = initCamera vw vh cstate
    , decGrid = createDecorativeGrid 500 100 (vector4 0.6 0.6 0.8 1)
    , city = emptyCity -- buildCity [] [] [] []
    , controls = Controls
        { selectedObject = 0
--        , activeService = radService
--        , availableServices = [radService, isovistService]
--        , placeTransform = Nothing
        }
    --, info = infoDef
    , userRole = userProfile
    } where -- radService = ServiceBox . RadianceService $ Vector3 0 3 5
            -- isovistService = ServiceBox (Isovist IMArea)




-- | Statefull view of the program; used in IO actions for displaying and interaction
data PView = PView
    { context      :: !ViewContext
    , dgView       :: !(View WiredGeometry)
    , cityView     :: !(View City)
--    , luciClient   :: !(Maybe LuciClient)
--    , luciScenario :: !(Maybe Scenario)
--    , scUpToDate   :: !Bool
    }


initView :: Program -> Canvas -> IO PView
initView prog@Program
    { camera = cam
    } canvas = do
    -- current time
    ctime <- getTime
    -- init GL
    gl <- getWebGLContext canvas
    -- init Context
    ctx <- setupViewContext gl cam ctime (vector3 (-0.5) (-1) 0.6)
    -- init object views
    dgview <- createView gl (decGrid prog)
    cview <- createView gl (city prog)
--    toJSRef (decGrid prog) >>= printRef
    -- done!
    return PView
        { context      = ctx
        , dgView       = dgview
        , cityView     = cview
--        , luciClient   = Nothing
--        , luciScenario = Nothing
--        , scUpToDate   = False
        }

--
--smallCity = buildCity [ building Dynamic $ SimplePolygon
--                             [ Vector3 0 1 0
--                             , Vector3 1 1 0
--                             , Vector3 1 2 2
--                             , Vector3 0 1.5 1
--                             ]
--                       , building Static $ SimplePolygon
--                             [ Vector3 (-1) 2   (-1)
--                             , Vector3   1  1.5 (-1)
--                             , Vector3   1  2     1
--                             , Vector3 (-1) 1.5   1
--                             ]
--                       , building Static $ SimplePolygon
--                             [ Vector3 (-1) 1   (-1)
--                             , Vector3   1  1.5 (-1)
--                             , Vector3   1  1     1
--                             , Vector3 (-1) 1.5   1
--                             ]
--                       , building Dynamic $ SimplePolygon
--                             [ Vector3 (-1) 2   (-1)
--                             , Vector3   0  1.5   2
--                             , Vector3   1  2   (-1)
--                             ]
--                       , building Dynamic $ SimplePolygon
--                             [ Vector3 (-1) 1   (-1)
--                             , Vector3   1  1.5 (-1)
--                             , Vector3   1  1     1
--                             ]]
--                       [ Vector3 0 0 1
--                       , Vector3 10 0 0
--                       , Vector3 0 0 5
--                       , Vector3 0 0 (-5)
--                       , Vector3 0 0 (-8)]
--                       [ 0.4
--                       , pi/4
--                       , 0
--                       , pi - 0.00000001
--                       , pi/2]
--                       [ [ Vector3 (-4) 0.1 (-12), Vector3 (-4) 0.1 10
--                         , Vector3 5 0.1 11, Vector3 7 0.1 8
--                         , Vector3 7 0.1 (-12), Vector3 (-4) 0.1 (-12)]
--                       , [ Vector3 11 0.1 10, Vector3 15 0.1 10
--                         , Vector3 15 0.1 14, Vector3 11 0.1 13, Vector3 11 0.1 10]
--                       ]