import "./index.css";
import { Composition } from "remotion";
import { BetsyPromo, TOTAL } from "./BetsyPromo";
import { BetsyTutorial, TUT_TOTAL } from "./BetsyPromo/tutorialComp";
import { BetsyCansado, CANSADO_TOTAL } from "./BetsyPromo/cansadoComp";
import { BetsyPov, POV_TOTAL } from "./BetsyPromo/povComp";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="BetsyPromo"
        component={BetsyPromo}
        durationInFrames={TOTAL}
        fps={30}
        width={1080}
        height={1920}
      />
      <Composition
        id="BetsyTutorial"
        component={BetsyTutorial}
        durationInFrames={TUT_TOTAL}
        fps={30}
        width={1080}
        height={1920}
      />
      <Composition
        id="BetsyCansado"
        component={BetsyCansado}
        durationInFrames={CANSADO_TOTAL}
        fps={30}
        width={1080}
        height={1920}
      />
      <Composition
        id="BetsyPov"
        component={BetsyPov}
        durationInFrames={POV_TOTAL}
        fps={30}
        width={1080}
        height={1920}
      />
    </>
  );
};
