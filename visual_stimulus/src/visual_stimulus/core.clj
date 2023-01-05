(ns visual_stimulus.core
  (:require [quil.core :as q]
            [quil.middleware :as m]
            [langohr.core      :as rmq]
            [langohr.channel   :as lch]
            [langohr.queue     :as lq]
            [langohr.consumers :as lc]
            [langohr.basic     :as lb]
            [genartlib.random :as gen]
            ))

;; (defn message-handler
;;   [ch {:keys [content-type delivery-tag type] :as meta} ^bytes payload]
;;   (println (format "[consumer] Received a message: %s, delivery tag: %d, content type: %s, type: %s"
;;                    (String. payload "UTF-8") delivery-tag content-type type)))
(def ^{:const true}
  default-exchange-name "")
(def amqp-url (get (System/getenv) "amqp://guest:guest@localhost:5672"))
(def conn (rmq/connect))
(def ch (lch/open conn))
(def qname "fish_queue")
;; (def iql_directory "/home/andrewbolton/inferenceql.auto-modeling/data/xcat/ensemble.edn")

(def envwidth 1260)
(def envheight 840)

;; can eventually update this with triangular and sinusoidal motion.
;; see wave code in diagonal.clj
(defn setup-visstim []
  (q/frame-rate 60)
  {:center_x 0
   :center_y (/ envheight 3)
   :epoch 0
   :translation_rate 3})

; want to do something like "if center_x > 0 < envwidth, add translation rate". 
; if == 0, if start detected, add 1. bump the epoch each time center_x is = envwidth. 

(defn update-state [state]
  (q/frame-rate 30)
  {:triwave (:triwave state)
   :translation_rate (:translation_rate state)
   ; change epoch function to get noises to switch faster
   ; have it be a mod over envwidth
   :epoch (cond (= (:center_x state) envwidth)
                (+ 1 (:epoch state))
                :else (:epoch state))
   :center_x (cond (= (:center_x state) 0)
                   (cond (lb/get ch qname)
                         (+ (:translation_rate state) (:center_x state))
                         :else 0)
                   (= (:center_x state) envwidth)
                   (do (print "edge")
                       0)
                   :else
                   (+ (:center_x state) (:translation_rate state)))
   :center_y (:center_y state)})

(defn draw-state [state]
  (q/background 0)
  (q/fill 255 255 255)
  (q/stroke 255 255 255)
  (let [prey-noise 0 
        global_noise 0]
    (q/with-translation [(gen/gauss (:center_x state) 0)
                         (gen/gauss (:center_y state) 0)]
      (q/ellipse (gen/gauss 0 prey-noise) 0 10 10))))



(q/defsketch visual_stimulus
  :title "You spin my circle right round"
  :size [envwidth envheight]
  ; setup function called only once, during sketch initialization.
  :setup setup-visstim
  ; update-state is called on each iteration before draw-state.
  :update update-state
  :draw draw-state
  :features [:keep-on-top]
  ; This sketch uses functional-mode middleware.
  ; Check quil wiki for more info about middlewares and particularly
  ; fun-mode.
  :middleware [m/fun-mode])
