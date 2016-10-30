<?php
// vim: filetype=php expandtab tabstop=2 shiftwidth=2 autoindent smartindent:

namespace Drupal\loadbalancing_cookie\EventSubscriber;

use Drupal\Core\Config\ConfigFactoryInterface;
use Symfony\Component\HttpFoundation\Cookie;
use Symfony\Component\HttpKernel\Event\FilterResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

/**
 * Provides a LoadBalancingResponseEventSubscriber.
 *
 * At the moment the cookies are hardcoded to one (1) month. This will be changed
 * to be configured within Drupal Administration pages in the future.
 */
class LoadBalancingResponseEventSubscriber implements EventSubscriberInterface {

  const NAME = "lbloc";
  const COOKIE_EXPIRE_SECS = 60 * 60 * 24 * 30; // one month cookie
  const PATH = "/";
  const DOMAIN = null;
  const SECURE = true; // only use on https
  const HTTP_ONLY = true; // don't let Javascript access it for cross-site scripting

  /**
   * The configuration factory.
   *
   * @var \Drupal\Core\Config\ConfigFactoryInterface
   */
  protected $configFactory;

  /**
   * Constructs a new class object.
   *
   * @param \Drupal\Core\Config\ConfigFactoryInterface $config_factory
   *   The configuration factory.
   */
  public function __construct(ConfigFactoryInterface $config_factory) {
    $this->configFactory = $config_factory;
  }

  public function setLoadbalancerCookie(FilterResponseEvent $event) {
    // check to see if loadbalancing_cookie_user_login marked this request as needing to set the cookie
    if (!$lbloc = $event->getRequest()->attributes->get('loadbalancing_cookie_location')) {
        return;
    }

    // create the cookie (similar to https://api.drupal.org/api/drupal/core%21lib%21Drupal%21Core%21Session%21SessionManager.php/class/SessionManager/8.2.x)
    $params = session_get_cookie_params();
    $expire = $params['lifetime'] ? REQUEST_TIME + $params['lifetime'] : 0;
    $cookie = new Cookie(self::NAME, $lbloc, $expire, $params['path'], $params['domain'], $params['secure'], $params['httponly']);

    // set the cookie
    $event->getResponse()->headers->setCookie($cookie);
  }

  /**
   * {@inheritdoc}
   */
  public static function getSubscribedEvents() {
    // You can set the order of execution of this event callback in the array.

    // Run before HtmlResponseSubscriber::onRespond(), which has priority 0.
    // Find the order of execution by doing this in the Drupal Root:
    //  grep '$events\[KernelEvents::RESPONSE\]\[\]' . -R | grep -v 'Test'
    $events[KernelEvents::RESPONSE][] = array('setLoadbalancerCookie', 100);
    return $events;
  }
}
